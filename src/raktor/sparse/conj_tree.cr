module Raktor::Sparse
  # Conjunction trees are key in *evaluating* a fact set.
  #
  # Disjunctions are converted to conjunctions during rewriting; and
  # inversion is contradiction, handled by the fact set itself. What
  # remains is conjunction.
  #
  # Conjunctions are represented by a tree where the most frequent
  # (rule-frequent) label is put first, grouping subordinate, less and
  # less frequently encountered labels. This always works because order
  # is not important in conjunctions; moreover, *all* members of a
  # conjunction must be true. Disjunctions are not that useful because
  # grouping them won't make a lot of sense.
  #
  # In some sense Sparse, if implemented this way, is recursive. The
  # filter system, built from many smaller filter systems, studies the
  # input term. Conjunction tree can also be viewed as a filter system,
  # whose input is the fact set and whose observations populate the
  # fact set.
  struct ConjTree
    def initialize
      @edges = {} of Label => ConjTree
      @outputs = Set(Label).new
    end

    # Clears the edges and outputs of this conjunction tree. The GC
    # should take care of the rest unless you reference some, and
    # if that is the case we shouldn't touch it anyway.
    def clear
      @edges.clear
      @outputs.clear
    end

    # Assigns an *output* (result) to this conjunction tree.
    def then(output : Label)
      @outputs << output
    end

    # Appends an edge between this conjunction tree and a new subtree
    # via the given *label*.
    def append(label : Label)
      @edges[label] ||= ConjTree.new
    end

    @_evaluate_iterable = [] of Label

    # Recursively evaluates this conjunction tree: decides which edge(s)
    # to take based on whether that edge is present in *facts*.
    def evaluate(facts : FactSet)
      # Appending outputs here *may* result in logical errors, but only
      # in feedback situations. For example:
      #
      # %0 = %1 & %2 & %3;
      # %3 = not(%0);
      #
      # Assume %1 and %2 are true, %3 is true due to %0 being unknown.
      # So we're rightfully following %1 and %2 and end up following %3,
      # this results in %0 evaluating to true, this causes not(%0) to
      # emit false, removing %3 from the fact set. In an ideal world we'd
      # like to react to this and backtrack, however, that's an unexpected
      # situation anyway (and I don't have any example of how it can be
      # synthesized); so let's just not spend the valuable compute on
      # this crap.
      facts.append(@outputs)
      if @edges.size > facts.size*2 # iterate edges > iterate facts twice (to_a + iterable.each)
        @_evaluate_iterable.clear
        iterable = facts.to_a(reuse: @_evaluate_iterable)
        iterable.each do |fact|
          next unless branch = @edges[fact]?
          branch.evaluate(facts)
        end
      else
        @edges.each do |edge, branch|
          next unless facts.includes?(edge)
          branch.evaluate(facts)
        end
      end
    end

    def to_s(io, indent = 0)
      @edges.each do |k, v|
        io << " " * indent << " -> " << k
        unless v.@outputs.empty?
          io << " ^ " << v.@outputs.join(", ")
        end
        if v.@edges.empty?
          io << ".\n"
        else
          io << " ->\n"
          v.to_s(io, indent + 2)
        end
      end
    end
  end
end
