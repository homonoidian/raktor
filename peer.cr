require "uuid"
require "./src/raktor"

class Raktor::Node
end

require "./src/raktor/recipe"

module Raktor
  include Protocol

  module Role
    abstract def handle(parcel : IParcel)
    abstract def kill
  end

  class Node::Control
    getter? disconnect = false

    def disconnect
      @disconnect = true
    end
  end

  class Node
    getter inbox : Chan(IParcel)

    def initialize(@roles : Array(Role))
      @inbox = Chan(IParcel).new
    end

    # A crude DSL for describing nodes in Crystal. For the
    # available methods see `Recipe`.
    #
    # ```
    # Node.should do
    #   sense "number"
    #   tweak { |n| n * Num[2] }
    #   show "> 100"
    # end
    # ```
    def self.should(&)
      recipe = Recipe.new
      with recipe yield
      node = Node.new([
        Role::Host.new,
        Role::Client.new(recipe),
        Role::PingSender.new,
        Role::PingReceiver.new,
      ] of Role)
      node.spawn
      node
    end

    def spawn
      spawn do
        while parcel = @inbox.receive
          @roles.each &.handle(parcel)
        end
      rescue e : Exception
        @roles.each &.kill
        raise e
      end
    end

    def_equals_and_hash object_id
  end

  record KeepConn, router : IRouter(IEndpoint(IParcel)), sender : UInt64, receiver : UInt64 do
    def send(message : Message)
      router.send(sender, receiver, message)
    end

    def reply(message : Message)
      router.send(receiver, sender, message)
    end

    def_equals_and_hash sender, receiver
  end

  class Node::Role::PingSender
    include Role

    PERIOD  = 500.milliseconds
    TIMEOUT = 2.seconds

    def initialize
      @killswitch = Channel(Bool).new
      @receivers = Channel(IParcel).new(32)
      @ping = Channel(Bool).new
      @advance = Channel(Bool).new

      spawn(keep, same_thread: true)
      spawn(ping, same_thread: true)
      spawn(advance, same_thread: true)
    end

    private def keep
      receivers = Set(KeepConn).new
      generation = Set(KeepConn).new

      while true
        select
        when @killswitch.receive
          break
        when conn = @receivers.receive
          receivers << KeepConn.new(conn.router, conn.sender, conn.receiver)
        when @ping.receive
          generation.each &.reply(Message[Opcode::Ping])
        when @advance.receive
          generation.clear
          generation.concat(receivers)
          receivers.clear
        end
      end
    end

    private def ping
      while true
        select
        when @killswitch.receive
          break
        when timeout(PERIOD)
          @ping.send(true)
        end
      end
    end

    private def advance
      while true
        select
        when @killswitch.receive
          break
        when timeout(TIMEOUT)
          @advance.send(true)
        end
      end
    end

    def kill
      @killswitch.send(true)
    end

    def handle(parcel)
      message = parcel.message

      case message.opcode
      when .init_self?, .pong?
        @receivers.send(parcel)
      end
    end
  end

  class Node::Role::PingReceiver
    include Role

    TIMEOUT = 2.seconds

    def initialize
      @killswitch = Channel(::Bool).new
      @survivors = Channel(IParcel).new(32)
      @purge = Channel(Bool).new

      spawn(keeper, same_thread: true)
      spawn(worker, same_thread: true)
    end

    private def keeper
      survivors = Set(KeepConn).new
      generation = Set(KeepConn).new

      while true
        select
        when @killswitch.receive
          break
        when survivor = @survivors.receive
          survivors << KeepConn.new(survivor.router, survivor.sender, survivor.receiver)
        when @purge.receive
          generation.each do |conn|
            next if conn.in?(survivors)
            conn.send(Message[Opcode::Disconnect])
          end
          generation.clear
          generation.concat(survivors)
          survivors.clear
        end
      end
    end

    private def worker
      while true
        select
        when @killswitch.receive
          break
        when timeout(TIMEOUT)
          @purge.send(true)
        end
      end
    end

    def kill
      @killswitch.send(true)
    end

    def handle(parcel)
      message = parcel.message

      case message.opcode
      when .connect?
        @survivors.send(parcel)
      when .ping?
        @survivors.send(parcel)
        parcel.reply(Message[Opcode::Pong])
      end
    end
  end

  class Node::Role::Client
    include Role
    include Terms

    def initialize(recipe : Recipe)
      @sensor_dict = {} of String => Recipe::Sensor
      @sensor_slots = {} of Int32 => Recipe::Sensor

      @appearance_map = Sparse::Map(Recipe::Appearance).new
      @appearance_dict = {} of String => Recipe::Appearance
      @appearance_rdict = {} of Recipe::Appearance => String
      @appearance_slots = {} of Int32 => Recipe::Appearance

      @kernel = recipe.kernel? || ->(term : Term, ctrl : Control) { term }

      recipe.each_sensor do |sensor|
        @sensor_slots[sensor.slot] = sensor
      end

      @appearance_map.batch do
        recipe.each_appearance do |appearance|
          @appearance_map[appearance] = appearance.filter
          @appearance_slots[appearance.slot] = appearance
        end
      end
    end

    private def activate(parcel, appearances : Array(Recipe::Appearance), result)
      appearances.each { |appearance| activate(parcel, appearance, result) }
    end

    private def activate(parcel, appearance : Recipe::Appearance, result)
      return unless id = @appearance_rdict[appearance]?

      parcel.reply(Message[Opcode::SetAppearance, appearance.mapper.call(result), Str[id]])
    end

    private def sense(parcel, sensor, term)
      return unless state = sensor.mapper.call(term)

      control = Control.new
      result = @kernel.call(state, control)

      if control.disconnect?
        parcel.reply(Message[Opcode::Disconnect])
        return
      end

      appearances = @appearance_map[result, report: Set(Recipe::Appearance).new]
      appearances.group_by(&.group_id?).each do |group_id, members|
        # If there is no group id specified, activate all appearances.
        if group_id.nil?
          activate(parcel, members, result)
          next
        end

        start = nil

        # Sort group's members by ordinal and pick leading elements with
        # the same ordinal.
        members.unstable_sort_by!(&.rel.not_nil!.ordinal)
        members.each do |member|
          ordinal = member.rel.not_nil!.ordinal
          break unless start.nil? || ordinal == start
          activate(parcel, member, result)
          start ||= ordinal
          break
        end
      end
    end

    def kill
    end

    def handle(parcel : IParcel)
      message = parcel.message

      case message.opcode
      when .init_self?
        @sensor_slots.each do |slot, sensor|
          parcel.reply(Message[Opcode::RegisterSensor, slot.to_u64, Str[sensor.filter]])
        end
        @appearance_slots.each do |slot, appearance|
          remnant = appearance.remnant
          terms = remnant ? [remnant] : [] of Term
          parcel.reply(Message.new(Opcode::RegisterAppearance, args: [slot.to_u64], terms: terms))
        end
      when .init_sensor?
        return unless id = message.terms[0]?.as?(Str)
        return if @sensor_dict.has_key?(id.value)
        return unless slot = message.args[0]?
        return unless sensor = @sensor_slots[slot]?

        @sensor_dict[id.value] = sensor

        message.terms.each(within: 1..) do |term|
          sense(parcel, sensor, term)
        end
      when .init_appearance?
        return unless id = message.terms[0]?.as?(Str)
        return if @appearance_dict.has_key?(id.value)
        return unless slot = message.args[0]?
        return unless appearance = @appearance_slots[slot]?

        @appearance_dict[id.value] = appearance
        @appearance_rdict[appearance] = id.value

        # If fully initialized send out defaults.
        if @appearance_dict.size == @appearance_slots.size
          @appearance_dict.each do |id, other|
            next unless default = other.default
            parcel.reply(Message[Opcode::SetAppearance, default, Str[id]])
          end
        end
      when .sense?
        return unless term = message.terms[0]?
        return unless id = message.terms[1]?.as?(Str)
        return unless sensor = @sensor_dict[id.value]?

        sense(parcel, sensor, term)
      end
    end
  end

  class Node::Role::Host
    include Role
    include Terms

    record Sensor, owner : UInt64, id = UUID.random.to_s
    record Appearance, owner : UInt64, remnant : Term? = nil, id = UUID.random.to_s do
      def_equals_and_hash owner, id
    end

    def initialize
      @map = Sparse::Map(Sensor).new
      @appearances = {} of Appearance => Term?
      @owned_sensors = {} of UInt64 => Set(Sensor)
      @owned_appearances = {} of UInt64 => Set(Appearance)
    end

    class BoolReport(T)
      include Sparse::IReport(T)

      @state = false

      def true?
        @state
      end

      def report(keys : Set(T))
        return if keys.empty?
        @state = true
      end
    end

    def kill
    end

    private def notify(parcel, term)
      sensors = @map[term, report: Set(Sensor).new]
      sensors.each do |sensor|
        parcel.reply(sensor.owner, Message[Opcode::Sense, term, Str[sensor.id]])
      end
    end

    def handle(parcel : IParcel)
      message = parcel.message

      case message.opcode
      when .connect?
        parcel.reply(Message[Opcode::InitSelf])
      when .disconnect?
        puts "[DISCONNECT] Disconnect #{parcel.sender}"
        if appearances = @owned_appearances.delete(parcel.sender)
          appearances.each do |appearance|
            @appearances.delete(appearance)
            next unless remnant = appearance.remnant
            notify(parcel, remnant)
          end
        end
        if sensors = @owned_sensors.delete(parcel.sender)
          @map.batch do
            sensors.each { |sensor| @map.delete(sensor) }
          end
        end
        parcel.disconnect
      when .register_appearance?
        return unless slot = message.args[0]?

        remnant = message.terms[0]?

        @appearances[appearance = Appearance.new(parcel.sender, remnant)] = nil

        ownerof = @owned_appearances[parcel.sender] ||= Set(Appearance).new
        ownerof << appearance

        parcel.reply(Message[Opcode::InitAppearance, slot, Str[appearance.id]])
      when .register_sensor?
        return unless slot = message.args[0]?
        return unless filter = message.terms[0]?.as?(Str)
        terms = [] of Term
        @map.upsert(sensor = Sensor.new(parcel.sender), filter.value) do |query|
          @appearances.each_value do |term|
            next unless term
            next unless query[term, report: BoolReport(Sensor).new].true?
            terms << term
          end
        end
        ownerof = @owned_sensors[parcel.sender] ||= Set(Sensor).new
        ownerof << sensor
        parcel.reply(
          Message.new(Opcode::InitSensor,
            args: [slot],
            terms: terms.unshift(Str[sensor.id])
          )
        )
      when .unregister_appearance?
      when .unregister_sensor?
      when .set_appearance?
        return unless term = message.terms[0]?
        return unless id = message.terms[1]?.as?(Str)
        return unless @appearances.has_key?(key = Appearance.new(parcel.sender, id: id.value))
        @appearances[key] = term

        notify(parcel, term)
      end
    end
  end
end

include Raktor
include Terms

# Todo: websocket router
# Todo: begin writing specs for Node, use channel for blocking
# Todo: add/remove own sensors, appearances at runtime
# Todo: node replicate & disconnect at runtime
# Todo: double queue backpressure
# Todo: language parser & interpreter with hot code reloading
# Todo: optimize insert & delete perf in Sparse::Map

# foo = Node.should do
#   show default: Num[0]
#   show default: Num[1]
#   show default: Num[2]
# end

# bar = Node.client do
#   sense %(number)
#   sense %("crash")
#   tweak do |n|
#     if n == Str["crash"]
#       raise "boom"
#     end
#     puts n
#     n
#   end
#   show %(not("crash")), remnant: Str["boo"]
# end

# baz = Node.should do
#   sense %("boo")
#   tweak do |n|
#     puts "HERE: #{n}"
#     n
#   end

#   show %(not("boo")), default: Str["crash"]
# end
