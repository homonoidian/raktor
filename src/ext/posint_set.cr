@[Link("stdc++")]
@[Link(ldflags: "'#{__DIR__}/google-posint-set.o'")]
lib GooglePosIntSet
  fun posint_set_new : Void*
  fun posint_set_finalize(set : Void*)
  fun posint_set_clear(set : Void*)
  fun posint_set_push(set : Void*, x : Int32)
  fun posint_set_includes(set : Void*, x : Int32) : Bool
  fun posint_set_delete(set : Void*, x : Int32) : Bool
  fun posint_set_iterate(set : Void*, iteratee : (Int32, Void* ->), data : Void*)
  fun posint_set_size(set : Void*) : LibC::SizeT
  fun posint_set_eq(a : Void*, b : Void*) : Bool
end

class PosIntSet
  def initialize
    @set = GooglePosIntSet.posint_set_new
  end

  def finalize
    GooglePosIntSet.posint_set_finalize(@set)
  end

  # Returns the size of this set.
  @[AlwaysInline]
  def size
    GooglePosIntSet.posint_set_size(@set)
  end

  # Returns whether this set includes the given *int*.
  @[AlwaysInline]
  def includes?(int : Int32) : Bool
    GooglePosIntSet.posint_set_includes(@set, int)
  end

  # Yields each int in this set.
  def each(&fn : Int32 ->)
    boxed_data = Box.box(fn)

    GooglePosIntSet.posint_set_iterate(@set, ->(item : Int32, data : Void*) do
      data_cb = Box(typeof(fn)).unbox(data)
      data_cb.call(item)
    end, boxed_data)
  end

  # Appends an *int* to this set.
  @[AlwaysInline]
  def <<(int : Int32)
    GooglePosIntSet.posint_set_push(@set, int)
  end

  # Removes the given *int* from this set if it was there.
  @[AlwaysInline]
  def delete(int : Int32)
    GooglePosIntSet.posint_set_delete(@set, int)
  end

  # Erases all elements in this set.
  @[AlwaysInline]
  def clear
    GooglePosIntSet.posint_set_clear(@set)
  end

  def to_s(io)
    io << "IntSet{"

    index = 0

    each do |item|
      index += 1
      io << item
      io << "," if index < size
    end

    io << "}"
  end
end
