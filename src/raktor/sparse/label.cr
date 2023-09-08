module Raktor::Sparse
  # An abstract, immutable mention of a value, used throughout Sparse
  # from AST-to-chain compilation all the way to the VM.
  struct Label
    include Comparable(Label)

    def initialize(@id : Int32)
    end

    def <=>(other : Label)
      @id <=> other.@id
    end

    # Returns whether this label's id is in *set*.
    def in?(set : PosIntSet)
      set.includes?(@id)
    end

    # Using this label's id as the index, fetches an element
    # from *indexable* without doing any bounds check.
    def unsafe_fetch(*, from indexable : Indexable(T)) : T forall T
      indexable.unsafe_fetch(@id)
    end

    # Using this label's id as the index, sets an element in
    # *indexable* to *value* without doing any bounds check.
    def unsafe_put(value : T, *, to indexable : Indexable::Mutable(T)) forall T
      indexable.unsafe_put(@id, value)
    end

    # Replaces this label with *other* in the given substitution
    # table *subst*.
    def replace_with(other : Label, *, in subst : Subst)
      subst.sub(self, other)
    end

    # Returns the substitution for this label in *subst*; if no
    # substitution, returns `self`.
    def apply(subst : Subst) : Label
      subst.for?(self) || self
    end

    # Attaches this label to *filter*.
    def transfer(*, to filter : Filter)
      filter.attach(self)
    end

    # Appends this label's id to *set*.
    def transfer(*, to set : PosIntSet)
      set << @id
    end

    # Appends this label to *set*.
    def transfer(set : Set(Label))
      set << self
    end

    # Removes this label's id from *set*.
    def delete(*, from set : PosIntSet)
      set.delete(@id)
    end

    # Returns a normalized version of this label, obtaining
    # an id using the given *getlabel* proc.
    #
    # See `RuleBook#norm`.
    def norm(getlabel) : Label
      getlabel.call(self)
    end

    def to_s(io)
      io << "%" << @id
    end
  end
end
