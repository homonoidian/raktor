module Raktor::Sparse
  # Filter is a two-dimensional, branching, collatable intermediate
  # representation of a Sparse program.
  class Filter
    private getter _equation : LabelSet { LabelSet.new }

    def initialize
      @edges = {} of Gate => Filter
    end

    # Attaches *label* to this filter.
    #
    # Whenever the input term (or a transformed/filtered version of it)
    # reaches this filter, *label* will be appropriately "notified" of
    # the fact. *label* is usually part of some rule in the rule book,
    # which makes it possible to group "observations" made using filters
    # into more abstract categories using "or", "and" combinators etc.
    def attach(label : Label) : self
      _equation << label

      self
    end

    # Connects this filter to another *filter* via the given *gate*.
    # Returns *filter* for further chaining.
    #
    # Whenever the input term (or a transformed/filtered version of it)
    # reaches this filter, it will then have to pass through *gate* in
    # order to get to *filter*.
    def connect(via gate : Gate, to filter : Filter) : Filter
      @edges[gate] ||= filter
    end

    # Merges the edges of this filter with *edges*, appends all
    # attached labels to *labels*.
    def transfer(edges : Hash(Gate, Filter), equation : LabelSet)
      if (__equation = @_equation) && !__equation.empty?
        equation << __equation
      end

      edges.merge!(@edges) { |k, v1, v2| v1.collate(v2) }
    end

    # Mutably merges *other* filter into this filter (this filter
    # is mutated).
    def collate(other : Filter) : self
      other.transfer(@edges, _equation)

      self
    end

    # Writes labels attached to this filter to *book* in form of an
    # equation (i.e. all labels attached to this filter are equal).
    # Recurses to all connected filters.
    #
    # ```text
    # IsNum ->
    #   -> DivBy(10) ->
    #     ^ (%0 %2)
    #   -> DivBy(15) ->
    #     ^ (%1)
    #
    # Equations:
    #
    # - %0 = %2
    # - %1
    # ```
    def defequations(book : RuleBook)
      if (__equation = @_equation) && !__equation.empty?
        book.defequation(__equation)
      end

      @edges.each_value &.defequations(book)
    end

    # Performs cleanup, namely removes branches that are not listened
    # to by any labels (branches whose equations are empty or absent).
    #
    # This is a fairly expensive operation as the entire filter tree
    # must be traversed. However, filter trees are generally small so
    # again, *generally*, you need not worry about this.
    def cleanup : Bool
      @edges.reject! { |_, filter| filter.cleanup }
      @edges.empty? && ((__equation = @_equation).nil? || __equation.empty?)
    end

    # Compactifies this filter and all output filters, recursively.
    #
    # This method is quite hard to explain verbally, so here's a "picture".
    #
    # ```text
    # /? 10 /? 20
    #
    # ===>
    #
    # IsNum ->
    #   -> DivBy(10)
    #     ^ (%0)
    #     -> IsNum
    #       -> DivBy(20)
    #         ^ (%1)
    #
    # ===> // compact
    #
    # IsNum ->
    #   -> DivBy(10)
    #     ^ (%0)
    #   -> DivBy(20)
    #     ^ (%1)
    # ```
    def compact(reuse compactees = [] of Filter)
      @edges.each do |gate, filter|
        next unless gate.passthrough?

        filter.extract(gate, to: compactees)

        compactees.each { |compactee| filter.collate(compactee) }
        compactees.clear
      end

      @edges.each_value &.compact(reuse: compactees)
    end

    # Recursively explores passthrough gates connected to this filter.
    # If *input* gate is encountered, the filter that it flows into
    # is detached from the filter where *input* was encountered, and
    # transferred to (appended to) *basket*. Non-passthrough gates
    # are skipped.
    def extract(input : Gate, *, to basket : Array(Filter))
      @edges.each do |gate, filter|
        next unless gate.passthrough?

        # Remove gates that are the same as the input on a
        # passthrough route.
        if input == gate
          @edges.delete(gate)

          basket << filter
        end

        filter.extract(input, to: basket)
      end
    end

    # Clears the edges of this filter. The rest is up to the GC. If no
    # pointers remain to further filters, they will be collected by
    # the GC.
    def clear
      @edges.clear
    end

    protected def compile(compiler, gate, target, escape _escape, catch = _escape)
      # Follow body with POP to restore the value of the main register
      # after a non-passthrough gate modified it.
      escape = _escape
      unless gate.passthrough?
        escape = compiler.chunk
        escape.emit(VarInstr[Machine::Opcode::POP])
        escape.emit(VarInstr[Machine::Opcode::J, _escape])
      end

      body = compile(compiler, escape: escape)

      # If the gate succeeds, then inform the runtime of the labels that
      # were matched. Only filter's own labels were matched, though, so
      # we still have to continue to explore filter's own gates etc.
      success = body
      if (__equation = @_equation) && !__equation.empty?
        success = compiler.chunk
        success.emit(VarInstr[Machine::Opcode::MATCH, compiler.const(__equation.to_set)])
        success.emit(VarInstr[Machine::Opcode::J, body])
      end

      gate.compile(compiler, to: target, ok: success, err: catch)
    end

    # :nodoc:
    def compile(compiler : Compiler, escape : Chunk, entry = false)
      # Split gates into overlapping and non-overlapping gates. Within the
      # non-overlapping portion, if any gate fails or succeeds *after* it
      # let through a term, we can jump straight to the overlap section
      # without needing to visit the rest of nonoverlap gates.
      nonoverlap, overlap = @edges.partition { |gate, _| gate.overlap.none? }

      nonoverlap_chunks = nonoverlap.map { compiler.chunk }
      overlap_chunks = overlap.map { compiler.chunk }

      # After we've visited all of non-overlapping chunks go to the first
      # overlapping chunk. Then follow the chain of the overlapping chunks.
      # After we've visited all overlapping chunks, go to the escape chunk.
      overlap_chunks << escape
      nonoverlap_chunks << overlap_chunks[0]

      # If this filter is an entry filter, we should unconditionally
      # MATCH its equation. Use the first nonoverlap chunk for this,
      # why not.
      if entry && (__equation = @_equation) && !__equation.empty?
        nonoverlap_chunks[0].emit(VarInstr[Machine::Opcode::MATCH, compiler.const(__equation.to_set)])
      end

      overlap.each_with_index do |(gate, filter), index|
        filter.compile(compiler, gate,
          target: overlap_chunks[index],
          escape: overlap_chunks[index + 1],
        )
      end

      nonoverlap.each_with_index do |(gate, filter), index|
        filter.compile(compiler, gate,
          target: nonoverlap_chunks[index],
          escape: overlap_chunks[0],
          catch: nonoverlap_chunks[index + 1],
        )
      end

      nonoverlap_chunks[0]
    end

    def to_s(io, indent = 0)
      if (__equation = @_equation) && !__equation.empty?
        io << " " * indent << "^ (" << __equation << ")\n"
      end
      @edges.each do |k, v|
        io << " " * indent << k << " ->\n"
        v.to_s(io, indent + 2)
      end
    end
  end
end
