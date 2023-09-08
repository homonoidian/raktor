struct Set(T)
  # Removes elements for which the block returns true.
  def reject!(& : T -> Bool) : self
    @hash.reject! { |k| yield k }

    self
  end
end

class Panama(InOut, Med)
  abstract struct Link(Med)
    def self.[](*args, **kwargs)
      new(*args, **kwargs)
    end
  end

  struct Exact(Med) < Link(Med)
    getter pattern

    def initialize(@pattern : Med)
    end

    def connect(state : Panama(InOut, Med), unwrap : InOut -> Med) forall InOut
    end
  end

  struct Many(Med) < Link(Med)
    getter pattern

    def initialize(@pattern : Med)
    end

    def connect(state : Panama(InOut, Med), unwrap : InOut -> Med) forall InOut
      cons = state[@pattern]
      if cons[@pattern]?
        raise ArgumentError.new("pattern has ambiguous boundary Many[x] x, consider removing the second x")
      end
      state.merge!(cons)    # Make it optional to allow zero matches i.e. *?
      cons[@pattern] = cons # Feedback
    end
  end

  struct Maybe(Med) < Link(Med)
    getter pattern

    def initialize(@pattern : Med)
    end

    def connect(state : Panama(InOut, Med), unwrap : InOut -> Med) forall InOut
      state.merge!(state[@pattern])
    end
  end

  def initialize(&unwrap : InOut -> Med)
    initialize(unwrap)
  end

  def initialize(@unwrap : InOut -> Med)
    @map = {} of Med => Panama(InOut, Med)
    @matches = [] of Array(InOut) -> InOut
  end

  def merge!(other : Panama(InOut, Med))
    @map.merge!(other.@map)
    @matches.concat(other.@matches)
  end

  delegate :[], :[]?, :[]=, to: @map

  def on(*pattern : Med | Link(Med), &match : Array(InOut) -> InOut)
    # Make a single pass over the pattern to generate primary (exact)
    # links, regardless of whether it is Exact, Maybe, or Many.
    last = pattern.reduce(self) do |state, step|
      step = step.is_a?(Link(Med)) ? step.pattern : step
      state[step] ||= Panama(InOut, Med).new(@unwrap)
    end
    last.@matches << match

    # Do a second pass over the pattern, making the necessary connections
    # for Maybe and Many.
    pattern.reduce(self) do |state, step|
      step = step.is_a?(Med) ? Exact.new(step) : step
      step.connect(state, @unwrap)
      state[step.pattern]
    end
  end

  def match?(element : InOut?, partial, whole, escape)
    unless element && (newstate = @map[@unwrap.call(element)]?)
      if @matches.empty?
        whole.concat(partial)
      else
        whole.concat(@matches.reduce([] of InOut) { |_, match| [match.call(partial)] })
      end
      partial.clear
      if escape.nil? || same?(escape)
        partial << element if element
        return escape
      end
      return escape.match?(element, partial, whole, escape)
    end
    partial << element
    newstate
  end

  def compress(elements : Array(InOut))
    state = self
    whole = [] of InOut
    partial = [] of InOut
    elements.each do |element|
      state = state.match?(element, partial, whole, escape: self)
    end
    unless partial.empty?
      state.match?(nil, partial, whole, escape: nil)
    end
    whole
  end
end

# "Double-buffered" hash. The main hash can be read and written to,
# while the auxillary hash is given to you in `transform!` and then
# swapped with the main hash.
class TransformableHash(K, V)
  def initialize
    @main = {} of K => V
    @aux = {} of K => V
  end

  # Modifies keys and values of this hash using the block.
  def transform!(& : K, V, Hash(K, V) -> {K, V}) : self
    @main.each do |k, v|
      nk, nv = yield k, v, @aux
      @aux[nk] = nv
    end
    @main, @aux = @aux, @main.clear
    self
  end

  forward_missing_to @main
end

# "Double-buffered" set. The main set can be read and written to,
# while the auxillary set is given to you in `transform!` and then
# swapped with the main set.
class TransformableSet(T)
  def initialize
    @main = Set(T).new
    @aux = Set(T).new
  end

  # Returns a mutable, unstable reference to the current main set.
  #
  # **You do not own the returned set! Use it in a read-only fashion
  # only, and only if this transformable set is never mutated anymore.**
  def to_unsafe_set
    @main
  end

  # Modifies items in this hash using the block.
  def transform!(& : T -> T) : self
    @main.each do |item|
      @aux << (yield item)
    end
    @main, @aux = @aux, @main.clear
    self
  end

  forward_missing_to @main
end
