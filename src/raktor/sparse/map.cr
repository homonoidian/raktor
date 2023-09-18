module Raktor::Sparse
  # Includers are reported to whenever a batch of `Sparse::Map` keys matches.
  module IReport(T)
    # Called whenever a batch of `Sparse::Map` keys matches.
    abstract def report(keys : Set(T))
  end

  # A high-level interface to Sparse.
  #
  # ```
  # map = Sparse::Map(Int32).new
  # map[0] = "/? 10"
  # map[1] = "/? 20"
  #
  # map[Term::Str.new("foo")] # => []
  # map[Term::Num.new(123)]   # => []
  # map[Term::Num.new(30)]    # => [1]
  # map[Term::Num.new(100)]   # => [0, 1]
  # ```
  class Map(Key)
    private struct Compiled(Key)
      def initialize(@vm : Machine::VM, @ir : Machine::IR, @conj : ConjTree, @book : RuleBook(Key))
        @initial = PosIntSet.new
        @working = PosIntSet.new
        @inverted = Hash(Label, Label).new

        book.each_rule_with_label(Rule::Comb::Not) do |rule, inverse|
          next unless invertee = rule.first_arg?

          # In %inverse = not(%invertee), %inverse is a match by default.
          # However, if we ever encounter %invertee, we turn %inverse off
          # (remove it from the fact set).
          @inverted[invertee] = inverse

          inverse.transfer(to: @initial)
        end
      end

      def query(terms : Enumerable(Term), report : IReport(Key))
        @initial.each { |item| @working << item }

        facts = FactSet.new(@book, @inverted, @working)

        # Run the compiled filter system to obtain a set of "facts"
        # or "observations".
        terms.each { |term| @vm.run(@ir, facts, term) }

        # Apply logic to the "facts"/"observations" to derive new
        # "facts"/"observations" etc., until that leads us to the
        # conclusion that an entire program matches.
        @conj.evaluate(facts)

        # For all programs that did match, report their respective keys.
        facts.report(report)

        @working.clear
      end

      def query(term : Term, report : IReport(Key))
        query({term}, report)
      end
    end

    @compiled : Compiled(Key)?

    def initialize
      @vm = Machine::VM.new
      @keys = Set(Key).new
      @conj = ConjTree.new
      @book = RuleBook(Key).new
      @filter = Filter.new
    end

    # Returns whether this map is empty.
    def empty?
      @book.each_tagset_with_label { return false }

      true
    end

    @_compile_chain = Chain.new

    private def compile(key : Key, program : String, filter : Filter, book : RuleBook(Key))
      success = Parser.ast(program).compile(@_compile_chain, book)

      book.tag(success, key)

      # Convert the "1D" chain representation to "2D" filter representation.
      @_compile_chain.transfer(to: filter)

      filter.compact
      filter.defequations(book)

      # Rewrite the book. This helps to get rid of dumb stuff such
      # as `%1 = %2 & %2` (rewritten to `%1 = %2` which triggers a
      # substitution of `%1` for `%2`).
      book.rewrite(
        BookRewriter::SameBodyRewriter.new,
        BookRewriter::BindingRewriter.new,
        BookRewriter::AndOrEmbedder.new,
        BookRewriter::NotEmbedder.new,
        BookRewriter::UnusedRuleRemover.new,
        BookRewriter::OrToAndRewriter.new,
      )
    ensure
      @_compile_chain.clear
    end

    @_collate_book = RuleBook(Key).new
    @_collate_filter = Filter.new

    # Compiles and collates *program* into this map. After this method
    # this map's global book and filter are going to be updated, but
    # they won't work optimally. One must
    private def collate(key : Key, program : String, &)
      compile(key, program, @_collate_filter, @_collate_book)

      yield @_collate_filter, @_collate_book

      @book.collate(@_collate_book)
      @filter.collate(@_collate_filter)
    ensure
      @_collate_book.clear
      @_collate_filter.clear
    end

    @_apply_freq = Hash(Label, Int32).new(0)
    @_apply_args = [] of {Int32, Label}

    private def compile(vm, filter, book, conj)
      ir = Compiler.compile(filter)

      # Compute the tally of arguments of "and" rules (suppose there
      # are no "or" rules anymore).
      book.each_rule_with_label(Rule::Comb::And) do |rule, label|
        rule.each_arg { |arg| @_apply_freq.update(arg, &.succ) }
      end

      conj.clear

      # Populate the conjunction tree based on the frequency of
      # arguments, so that the arguments that are most frequent
      # come first (and therefore group more rules together).
      book.each_rule_with_label(Rule::Comb::And) do |rule, label|
        tree = conj
        rule.each_arg_by(@_apply_freq, reuse: @_apply_args) do |arg|
          tree = tree.append(arg)
        end
        tree.then(label)
      end

      Compiled.new(vm, ir, conj, book)
    ensure
      @_apply_freq.clear
      @_apply_args.clear
    end

    # Updates the compiled version of this map. Most notably, the
    # compiled version is queried in `[]`.
    private def invalidate
      return unless @batch.zero?

      @compiled = compile(@vm, @filter, @book, @conj)
    end

    @batch = 0

    # Enables batch mode. Certain operations, such as `delete`, are
    # quite expensive to do many times in a row. This is because they
    # recompile the entire map after they're done. In batch mode they
    # don't recompile until you leave the batch mode, i.e., until the
    # outermost batch is finished.
    #
    # ```
    # map = Sparse::Map(Int32).new
    # map[0...1000] = (0...1000).map { %Q({ "fname": "John", "lname": string, "age": /? 10 }) }
    # map.batch do
    #   # This won't recompile a thousand times. That'll happen only
    #   # once -- after the batch block finishes.
    #   (0...1000).each { |n| map.delete(n) }
    # end
    # ```
    def batch(&)
      @batch += 1
      yield
      @batch -= 1
      if @batch.zero?
        invalidate
      end
    end

    # Maps the given Sparse *program* to *key*. If *key* is already
    # present in this map, then its program is replaced with *program*.
    #
    # This version of `[]=` is not optimized for consecutive insertions.
    # If you want to map many programs to many keys simultaneously,
    # use the other variant of `[]=`.
    #
    # ```
    # map = Sparse::Map(Int32).new
    # map[0] = "/? 10"
    # map[1] = "/? 20"
    #
    # map[Term::Str.new("foo")] # => []
    # map[Term::Num.new(123)]   # => []
    # map[Term::Num.new(30)]    # => [1]
    # map[Term::Num.new(100)]   # => [0, 1]
    #
    # map[0] = %Q("foo")
    #
    # map[Term::Str.new("foo")] # => [0]
    # map[Term::Num.new(123)]   # => []
    # map[Term::Num.new(30)]    # => [1]
    # map[Term::Num.new(100)]   # => [1]
    # ```
    def []=(key : Key, program : String)
      batch do
        delete(key) unless @keys.add?(key)
        collate(key, program) { }

        @book.swap_equations(@filter)
        @book.rewrite
      end
    end

    # Same as `[]=`, but optimized for mapping many *keys* to many
    # *programs* simultaneously.
    #
    # ```
    # map = Sparse::Map(Int32).new
    # map[{0, 1}] = {"/? 10", "/? 20"}
    #
    # map[Term::Str.new("foo")] # => []
    # map[Term::Num.new(123)]   # => []
    # map[Term::Num.new(30)]    # => [1]
    # map[Term::Num.new(100)]   # => [0, 1]
    # ```
    def []=(keys : Enumerable(Key), programs : Enumerable(String))
      unless keys.size == programs.size
        raise IndexError.new("the number of keys is not equal to the number of programs")
      end

      batch do
        keys.zip(programs) do |key, program|
          delete(key) unless @keys.add?(key)
          collate(key, program) { }
        end

        @book.swap_equations(@filter)
        @book.rewrite
      end
    end

    # Helps you query the "intermediate map" constructed by `Map#upsert`.
    struct UpsertQuery(Key)
      def initialize(@compiled : Compiled(Key))
      end

      # Same as `Map#[]`, but runs on the intermediate map.
      def [](term : Term | Enumerable(Term), report : IReport(Key) = [] of Key) : IReport(Key)
        @compiled.query(term, report)

        report
      end
    end

    # Updates or inserts the mapping between *key* and *program*. Before
    # doing so, yields `UpsertQuery` which wraps an "intermediate map"
    # of sorts. This intermediate map contains exclusively the mapping
    # between *key* and *program*, so you can use it to query *program*
    # specifically before it is collated into the main map.
    def upsert(key : Key, program : String, & : UpsertQuery(Key) ->)
      batch do
        delete(key) unless @keys.add?(key)
        collate(key, program) do |filter, book|
          compiled = compile(@vm, filter, book, ConjTree.new)
          yield UpsertQuery.new(compiled)
        end

        @book.swap_equations(@filter)
        @book.rewrite
      end
    end

    # Reports all keys whose corresponding programs match the given *term*.
    # If *report* is given, then the matching keys are reported to it
    # (see `IReport#report`); otherwise, they are added to a new array.
    #
    # If *term* is `Enumerable`, the returned report will contain keys that
    # matched *any* of the terms in the enumerable, i.e., the information
    # about *which* specific term the given key matched is lost in exchange
    # for a small boost of performance.
    #
    # ```
    # # map : Sparse::Map(T)
    #
    # map[Term::Num.new(123)]                       # => [...]
    # map[{Term::Num.new(123), Term::Num.new(456)}] # => [...]
    # map[Term::Num.new(123), report: Set(T).new]   # => Set{...} (same as report)
    # ```
    def [](term : Term | Enumerable(Term), report : IReport(Key) = [] of Key) : IReport(Key)
      if compiled = @compiled
        compiled.query(term, report)
      end

      report
    end

    # Removes the given *key* and the Sparse program associated with
    # it. Returns `true` if *key* was present in this map, or `false`
    # in case it was absent.
    #
    # ```
    # map = Sparse::Map(Int32).new
    # map[0] = "/? 100"
    # map[1] = "/? 200"
    #
    # map[Term::Num.new(200)] # => [0, 1]
    #
    # map.delete(1)
    # map[Term::Num.new(200)] # => [0]
    #
    # map.delete(0)
    # map[Term::Num.new(200)] # => []
    #
    # map.empty? # => true
    # ```
    def delete(key : Key) : Bool
      return false unless @keys.delete(key)

      @book.untag(key)
      @filter.cleanup
      invalidate

      true
    end
  end
end

class Array(T)
  include Raktor::Sparse::IReport(T)

  def report(keys : Set(T))
    concat(keys)
  end
end

struct Set(T)
  include Raktor::Sparse::IReport(T)

  def report(keys : Set(T))
    concat(keys)
  end
end
