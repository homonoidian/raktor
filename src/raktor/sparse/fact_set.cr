module Raktor::Sparse
  # Represents a set of facts (facts being represented by simple integers
  # internally and exposed as `Label`s).
  #
  # *Facts* describe the presence or absence of certain properties in the
  # input term. For instance, the term being an integer is a possible *fact*.
  # Facts are then combined, using logic, into more and more abstract facts,
  # allowing to further categorize the input term (e.g. treat `(a number [fact])
  # (divisible by 5 [fact]) [fact]`).
  #
  # A fact set cannot contain contradictory facts (for instance in `5 [fact X]`
  # and `not(5 [fact X]) [fact Y]`, facts X and Y are contradictory). Only X
  # will remain in the set. Please note that dependency tracking is currently
  # not implemented; so if Y caused some facts to be added to the fact set,
  # and then was contradicted by X, those facts that Y added are *not* going
  # to be removed.
  struct FactSet(Tag)
    def initialize(@book : RuleBook(Tag), @inverted : Hash(Label, Array(Label)), @facts : PosIntSet) forall Tag
    end

    # Same as in `PosIntSet`.
    delegate :size, to: @facts

    @[AlwaysInline]
    def includes?(fact : Label)
      fact.in?(@facts)
    end

    # Adds *fact* to this fact set. Removes all contradicting facts.
    def append(fact : Label)
      fact.transfer(to: @facts)
      if inverses = @inverted[fact]?
        inverses.each &.delete(from: @facts)
      end
    end

    # Adds all facts from *facts* to this fact set. Removes all
    # contradicting facts.
    def append(facts : Set(Label))
      facts.each { |fact| append(fact) }
    end

    # Converts this fact set to a new array and returns it. If *reuse*
    # is given, adds facts to *reuse* instead.
    def to_a(reuse facts = Array(Label).new(size)) : Array(Label)
      @facts.each do |int|
        facts << Label.new(int)
      end
      facts
    end

    # Looks up the tags associated with each fact in this fact set, and
    # reports them to *report*.
    def report(report : IReport(Tag))
      @facts.each do |fact|
        next unless tagset = @book.tagset_for?(Label.new(fact))
        report.report(tagset)
      end
    end

    def to_s(io)
      io << "<FactSet facts=" << @facts << ">"
    end
  end
end
