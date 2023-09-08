module Raktor::Sparse
  # Represents a label substitution table.
  struct Subst
    def initialize
      @subst = {} of Label => Label
    end

    # Returns the substitution for *label*, if there is one. Otherwise,
    # returns nil.
    def for?(label : Label) : Label?
      @subst[label]?
    end

    # Schedules the substitution of *pattern* with *replacement*.
    def sub(pattern : Label, replacement : Label) : self
      @subst[pattern] = replacement

      self
    end

    # Applies substitutions from this substitution table to *book*.
    # Returns whether any substitutions were applied.
    def pop(book : RuleBook) : Bool
      return false if @subst.empty?

      book.apply(self)

      @subst.clear

      true
    end
  end
end
