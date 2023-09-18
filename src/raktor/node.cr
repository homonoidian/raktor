module Raktor
  include Protocol

  struct Remote
    include IParcelEndpoint

    def initialize(@socket : HTTP::WebSocket)
      @id = UUID.random
    end

    def receive(parcel : Parcel)
      @socket.stream do |io|
        parcel.message.to_cannon_io(io)
      end
    rescue IO::Error
    end

    def disconnect(endpoint : IParcelEndpoint)
      @socket.close # ???
    end

    def to_s(io)
      io << "<Remote id=" << @id << ">"
    end

    def_equals_and_hash @id
  end

  class Node
    include IParcelEndpoint

    def initialize(@roles : Array(Role))
      @inbox = Inbox(Parcel).new
    end

    # A crude DSL for describing nodes in Crystal. For the available
    # methods see `Recipe`.
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

    def join(host : IParcelEndpoint)
      send(host, Message[Opcode::Connect])
    end

    def join(uri : URI)
      spawn do
        socket = HTTP::WebSocket.new(uri)
        remote = Remote.new(socket)
        socket.on_binary do |bin|
          io = IO::Memory.new(bin)
          message = Message.from_cannon_io(io)
          # puts message
          # hex = IO::Hexdump.new(io, output: STDERR, read: true)
          # hex.gets_to_end
          # io.rewind
          remote.send(self, message)
        end
        join(remote)
        socket.run
      end
    end

    def bind(uri : URI)
      spawn do
        sockets = HTTP::WebSocketHandler.new do |socket, ctx|
          remote = Remote.new(socket)

          socket.on_binary do |bin|
            io = IO::Memory.new(bin)
            message = Message.from_cannon_io(io)
            # puts message
            # hex = IO::Hexdump.new(io, output: STDERR, read: true)
            # hex.gets_to_end
            # io.rewind
            remote.send(self, message)
          end

          socket.on_close do
            remote.send(self, Message[Opcode::Disconnect])
          end
        end

        server = HTTP::Server.new([sockets])
        server.bind(uri)
        server.listen
      end
    end

    # Todo: give control of the server to the outside world
    # Todo: how to bridge between worlds securely?

    def receive(parcel : Parcel)
      @inbox.send(parcel)
    end

    def spawn
      spawn do
        while parcel = @inbox.receive
          @roles.each &.handle(parcel)
        end
      rescue e : Exception
        @roles.each &.cut
        raise e
      end
    end

    def_equals_and_hash object_id
  end

  class Node::Role::PingSender
    include Role

    PERIOD  = 500.milliseconds
    TIMEOUT = 2.seconds

    def initialize
      @killswitch = Channel(Bool).new
      @receivers = Channel(Parcel).new(32)
      @ping = Channel(Bool).new
      @advance = Channel(Bool).new

      spawn(keep, same_thread: true)
      spawn(ping, same_thread: true)
      spawn(advance, same_thread: true)
    end

    private def keep
      receivers = Set(Link).new
      generation = Set(Link).new

      while true
        select
        when @killswitch.receive
          break
        when receiver = @receivers.receive
          receivers << receiver.link
        when @ping.receive
          generation.each &.reply(Message[Opcode::Ping])
        when @advance.receive
          generation.each do |conn|
            next if conn.in?(receivers)
            conn.reuse(Message[Opcode::Disconnect])
          end
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

    def cut
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
      @survivors = Channel(Parcel).new(32)
      @purge = Channel(Bool).new

      spawn(keeper, same_thread: true)
      spawn(worker, same_thread: true)
    end

    private def keeper
      survivors = Set(Link).new
      generation = Set(Link).new

      while true
        select
        when @killswitch.receive
          break
        when survivor = @survivors.receive
          survivors << survivor.link
        when @purge.receive
          generation.each do |conn|
            next if conn.in?(survivors)
            conn.reuse(Message[Opcode::Disconnect])
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

    def cut
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

      @kernel = recipe.kernel? || ->(term : Term, ctrl : Control) { term.as(Term?) }

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
      result = @kernel.call(state, control) || state

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

    def handle(parcel : Parcel)
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

    record Sensor, owner : IParcelEndpoint, id = UUID.random.to_s
    record Appearance, owner : IParcelEndpoint, remnant : Term? = nil, id = UUID.random.to_s do
      def_equals_and_hash owner, id
    end

    def initialize
      @map = Sparse::Map(Sensor).new
      @appearances = {} of Appearance => Term?
      @owned_sensors = {} of IParcelEndpoint => Set(Sensor)
      @owned_appearances = {} of IParcelEndpoint => Set(Appearance)
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

    private def notify(parcel, term)
      sensors = @map[term, report: Set(Sensor).new]
      sensors.each do |sensor|
        parcel.reply(sensor.owner, Message[Opcode::Sense, term, Str[sensor.id]])
      end
    end

    def handle(parcel : Parcel)
      message = parcel.message

      case message.opcode
      when .connect?
        parcel.reply(Message[Opcode::InitSelf])
      when .disconnect?
        # puts "[DISCONNECT] Disconnect #{parcel}"
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
        parcel.link.break
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

  module Node::Role
    abstract def handle(parcel : Parcel)

    def cut
    end
  end

  class Node::Control
    getter? disconnect = false

    def disconnect
      @disconnect = true
    end
  end

  # Represents a node's inbox.
  struct Node::Inbox(T)
    def initialize(@capacity : Int32 = 2**16)
      @queue = Channel(T).new(@capacity)
    end

    # Puts *object* into this inbox (FIFO push). Normally this won't
    # block, but if the capacity of this inbox is exceeded it will.
    def send(object : T)
      @queue.send(object)
    end

    # Takes and returns the first object from this inbox (FIFO pop).
    def receive : T
      @queue.receive
    end
  end
end
