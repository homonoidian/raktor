module Raktor::Sparse
  # Chains are a one-dimensional (sequential) representation of filters.
  # Chains can be nested. Nested chains are still one-dimensional, but
  # may lay themselves out on a different `Axis`.
  class Chain
    # Lists possible slots a `Gate` can occupy in a contiguous chunk
    # of gates. Order matters, and is exactly gate order (think of it
    # like gate precedence).
    enum Slot
      First

      Fetch
      Typecheck
      PropertyCategory
      Property
      Magnitude
      Exact

      Last
    end

    # Represents chain axis. Filters are two-dimensional but chains are
    # one-dimensional. `Axis` determines which of the two axes to use
    # when appending the chain to a `Filter`.
    enum Axis
      # Use the X axis.
      #
      # ```text
      #                       +-+   +-+   +-+
      # Chain(A, B, C) ==> +->+A+-->+B+-->+C+-->
      #                       +-+   +-+   +-+
      # ```
      X

      # Use the Y axis.
      #
      # ```text
      # Chain(A, B, C) ==>       +-+
      #                    +--+->+A+->
      #                       |  +-+
      #                       |
      #                       |  +-+
      #                       +->+B+->
      #                       |  +-+
      #                       |
      #                       |  +-+
      #                       +->+C+->
      #                          +-+
      # ```
      Y
    end

    def initialize(@axis = Axis::X)
      @members = [] of Chain | Gate | Label
    end

    @gates_start_at = 0

    # Adds a new *member* to the end of this chain.
    def append(member : Gate)
      # Find where to insert the gate in the contiguous chunk of gates.
      insert_at = (@gates_start_at...@members.size).bsearch do |index|
        gate = @members.unsafe_fetch(index).as(Gate)
        gate.slot >= member.slot
      end

      insert_at ||= @members.size

      @members.insert(insert_at, member)

      member
    end

    # :ditto:
    def append(member : Chain | Label)
      @members << member
      @gates_start_at = @members.size

      member
    end

    # Appends members of this chain and all nested chains recursively,
    # assuming *filter* to be the root or the 'point of departure".
    def transfer(*, to filter : Filter) : Filter
      case @axis
      in .x? then @members.reduce(filter) { |input, member| member.transfer(to: input) }
      in .y? then @members.each_with_object(filter) { |member, bus| member.transfer(to: bus) }
      end
    end

    # Removes all members of this chain and resets this chain to its
    # initial state. This allows you to e.g. reuse the chain object,
    # saving on allocations & GC work.
    def clear
      @members.clear
      @gates_start_at = 0
    end

    def to_s(io)
      io << @axis << "[" << @members.join(" -> ") << "]"
    end
  end
end
