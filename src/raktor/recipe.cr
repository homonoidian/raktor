module Raktor
  # A crude DpSL for describing nodes in Crystal.
  #
  # See `Node.should` for an example.
  class Node::Recipe
    # :nodoc:
    record Rel, group_id : Int32, ordinal : Int32

    # :nodoc:
    struct Sensor
      getter filter, mapper, slot

      def initialize(
        @filter : String,
        @mapper : Term -> Term,
        @slot : Int32
      )
      end

      def_equals_and_hash slot
    end

    # :nodoc:
    struct Appearance
      getter filter, mapper, slot, rel, default, remnant

      def initialize(
        @filter : String,
        @mapper : Term -> Term,
        @slot : Int32,
        @rel : Rel? = nil,
        @default : Term? = nil,
        @remnant : Term? = nil
      )
      end

      # Returns the group id assigned to this appearance, or nil if none.
      def group_id?
        rel.try(&.group_id)
      end

      def_equals_and_hash slot
    end

    # :nodoc:
    getter? kernel : (Term, Control -> Term?)?

    def initialize
      @sensors = [] of Sensor
      @appearances = [] of Appearance
    end

    # :nodoc:
    def each_sensor(& : Sensor ->)
      @sensors.each { |sensor| yield sensor }
    end

    # :nodoc:
    def each_appearance(& : Appearance ->)
      @appearances.each { |appearance| yield appearance }
    end

    # Creates and returns an appearance relationship object with the
    # given *group id* and *ordinal*.
    #
    # Appearances whose *group ids* are the same are treated as mutually
    # exclusive. In such case, if multiple appearances match, the first-
    # by-ordinal one (ordinals ascending) is selected. If there are multiple
    # appearances with the same ordinal within the same group, all of them
    # are activated.
    def relate(group_id : Int32, ordinal : Int32)
      Rel.new(group_id, ordinal)
    end

    # Will define a sensor with the given *filter* and *mapper*.
    #
    # ```
    # Node.should do
    #   sense "number"
    #   sense "string", &.as_s.to_i
    # end
    # ```
    def sense(filter : String = "any", &mapper : Term -> Term)
      @sensors << Sensor.new(filter, mapper, slot: @sensors.size)
    end

    # :ditto:
    def sense(filter : String = "any")
      sense(filter, &.itself)
    end

    # Will define an appearance with the given *filter* and *mapper*. Remember
    # that appearance filters are turned inward (toward the node's kernel),
    # and mappers are turned outward (toward the world).
    #
    # ```
    # Node.should do
    #   sense "number"
    #   show "/? 10"
    #   show "/? 100" { |n| Str["Divisible by 100: #{n}"] }
    # end
    # ```
    #
    # *default* term is sent right after the appearance is initialized. It could
    # be particularly useful if you want to kick-start a feedback.
    #
    # *remnant* term is the term left after this appearance disappears for
    # whatever reason. You can use *remnant* to tell everyone who's looking
    # that the appearance is no longer there, preventing stale state etc.
    #
    # *rel* specifies how the appearance will relate to all other appearances
    # of the same node. See `relate`.
    def show(
      filter : String = "any",
      default : Term? = nil,
      remnant : Term? = nil,
      rel : Rel? = nil,
      &mapper : Term -> Term
    )
      @appearances << Appearance.new(filter, mapper,
        rel: rel,
        slot: @appearances.size,
        remnant: remnant,
        default: default,
      )
    end

    # :ditto:
    def show(*args, **kwargs)
      show(*args, **kwargs, &.itself)
    end

    # Will define a node kernel.
    #
    # ```
    # Node.should do
    #   sense %({ n: number }), &.as_d.n
    #   tweak { |n| n * Num[2] }
    #   show "> 100"
    # end
    # ```
    def tweak(&@kernel : Term, Control -> Term?)
    end

    def tweak(cls : T.class, &kernel : T, Control -> Term?) forall T
      tweak { |term, ctrl| kernel.call(term.as(T), ctrl) }
    end
  end
end
