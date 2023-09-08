# Provides lighter objects for no-entry and single-entry hashes instead
# of a full featured `Hash`.
module Mapping(K, V)
  # Same as `Hash#[]?`.
  abstract def []?(key : K) : V?

  # Same as `Hash#size`.
  abstract def size : Int32

  # Same as `Hash#each`.
  abstract def each(& : K, V ->)

  # Same as `Hash#[]=`, returns the resulting mapping.
  abstract def put(key : K, value : V) : Mapping(K, V)

  # Same as `Hash#keys`.
  abstract def keys

  # :nodoc:
  abstract def smapv(& : V -> T) forall T

  # Same as `Hash#empty?`.
  def empty? : Bool
    size.zero?
  end

  # Transforms value(s) of this mapping using the block and returns
  # a new mapping. Same as `Hash#transform_values`.
  def mapv(&block : V -> T) : Mapping(K, T) forall T
    smapv(&block).as(Mapping(K, T))
  end

  # Merges this and *other* mappings, returns the new mapping. If mutation
  # is possible, `self` is mutated (hence the bang).
  def merge!(other : Mapping(K, V)) : Mapping(K, V)
    memo = self
    other.each do |k, v|
      memo = memo.put(k, v)
    end
    memo
  end
end

# Represents an empty mapping: mimics a hash with no entries.
class Mapping::Empty(K, V)
  include Mapping(K, V)

  def []?(key : K) : V?
  end

  def size : Int32
    0
  end

  def each(& : K, V ->)
  end

  def keys
    [] of K
  end

  def put(key : K, value : V) : Mapping(K, V)
    One.new(key, value)
  end

  def smapv(& : V -> T) forall T
    Empty(K, T).new
  end

  # Empty mappings are compared by identity.
  def_equals_and_hash object_id
end

# Represents a single-entry mapping: mimics a hash with a single entry.
struct Mapping::One(K, V)
  include Mapping(K, V)

  def initialize(@key : K, @value : V)
  end

  def []?(key : K) : V?
    key == @key ? @value : nil
  end

  def size : Int32
    1
  end

  def each(& : K, V ->)
    yield @key, @value
  end

  def keys
    [@key]
  end

  def put(key : K, value : V) : Mapping(K, V)
    Many.new({@key => @value, key => value})
  end

  def smapv(& : V -> T) forall T
    One(K, T).new(@key, (yield @value))
  end

  def_equals_and_hash @key, @value
end

# Represents a multi-entry mapping: a basic wrapper around a `Hash`.
struct Mapping::Many(K, V)
  include Mapping(K, V)

  def initialize(@hash : Hash(K, V))
  end

  def size : Int32
    @hash.size
  end

  def []?(key : K) : V?
    @hash[key]?
  end

  def each(& : K, V ->)
    @hash.each { |k, v| yield k, v }
  end

  def keys
    @hash.keys
  end

  def put(key : K, value : V) : Mapping(K, V)
    @hash[key] = value

    self
  end

  def smapv(& : V -> T) forall T
    Many(K, T).new(@hash.transform_values { |v| yield v })
  end

  def_equals_and_hash @hash
end
