module Raktor::Sparse
  # An unordered, non-repeating list of labels.
  struct LabelSet
    include Enumerable(Label)

    def initialize
      @labels = TransformableSet(Label).new
    end

    delegate :clear, :reject!, to: @labels

    def each(& : Label ->)
      @labels.each { |label| yield label }
    end

    # Appends *other* to this label set.
    def <<(other : Label) : self
      @labels << other

      self
    end

    # Appends all labels from *other* label set to this label set.
    def <<(other : LabelSet) : self
      @labels.concat(other.@labels)

      self
    end

    # Normalizes labels in this label set, obtaining ids using
    # the given *getlabel* proc.
    def norm(getlabel) : self
      @labels.transform! &.norm(getlabel)

      self
    end

    # Removes all labels from this set that are present in *candidates*.
    # Returns whether this set is empty afterwards.
    def reject?(candidates : Set(Label)) : Bool
      @labels.reject! { |label| label.in?(candidates) }
      @labels.empty?
    end

    # Substitutes all labels in this label set with one common label,
    # submits the substitutions to *subst*. Clears the content of this
    # set, leaving only the common label.
    def unify(book : RuleBook, *, into subst) : self
      common = book.newlabel

      each &.replace_with(common, in: subst)
      clear
      self << common
    end

    # Converts this label set to a Crystal `Set(Label)`.
    def to_set : Set(Label)
      @labels.to_unsafe_set.dup
    end

    def to_s(io)
      @labels.join(io, ", ")
    end

    def_equals_and_hash @labels
  end
end
