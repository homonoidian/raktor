require "colorize"

module Raktor
  struct Chan(T)
    def initialize(@capacity : Int32 = 2**16)
      # @queue = Disruptor::Queue(T).new(@capacity, Disruptor::WaitWithYield.new)
      @queue = Channel(T).new(@capacity)
      # I hate that channel blocks but it's the only thing that doesn't break,
      # overflow, or do any other kinky shit these kinds of data structures
      # tend to do under heavy load.
    end

    def send(object : T)
      # @queue.push(object)
      @queue.send(object)
    end

    def receive : T
      # @queue.pop
      @queue.receive
    end
  end

  class MapServer
    include Protocol

    struct Mediator
      def initialize(@server : MapServer, @parcel : IParcel)
      end

      private def genid(name : Symbol)
        if @server.@env[name]?
          raise ArgumentError.new("#{name} is already registered")
        end
        id = @server.@env[name] = @server.genid
        @server.@reverse_env[id] = name
        id
      end

      private def idof(name : Symbol)
        @server.@env[name]
      end

      def senses(name : Symbol, program : String)
        @parcel.reply(@parcel.sender, Message[Opcode::RegisterSensor, genid(name), Term::Str.new(program)])
      end

      def appears_as(name : Symbol)
        @parcel.reply(@parcel.sender, Message[Opcode::RegisterAppearance, genid(name)])
      end

      def set(name : Symbol, term : Term)
        @parcel.reply(@parcel.sender, Message[Opcode::SetAppearance, idof(name), term])
      end

      def to_s(io)
        io << "<mediator for comm with " << @parcel.receiver << ">"
      end
    end

    ID_BATCH_SIZE = 1024

    record Sensor, id : UInt64, owner : UInt64 do
      def_equals_and_hash id
    end

    def initialize
      @id = 0u64
      @map = Sparse::Map(Sensor).new
      @appearances = {} of UInt64 => Term?
      @queue = Chan(IParcel).new
      @used = Set(UInt64).new
      @free = Set(UInt64).new
    end

    def reply(med, opcode, *args)
      med.reply(med.sender, Message[opcode, *args])
    end

    def on_init(&@on_init : Mediator ->)
    end

    def on_init_sensor(&@on_init_sensor : Mediator ->)
    end

    def on_init_appearance(&@on_init_appearance : Mediator ->)
    end

    def on_sense(&@on_sense : Term, Mediator, Symbol? ->)
    end

    @env = Hash(Symbol, UInt64).new
    @reverse_env = Hash(UInt64, Symbol).new

    private def mediate(med, cb)
      mediator = Mediator.new(self, med)
      cb.call(mediator)
    end

    protected def genid
      if @free.empty?
        raise "TODO: request more ids (ran out of server-allocated unique ids)"
      end
      id = @free.sample
      @free.delete(id)
      id
    end

    def spawn
      spawn do
        while med = @queue.receive
          message = med.message

          case message.opcode
          in .request_unique_id_range?
            b = @id
            e = @id += ID_BATCH_SIZE
            reply(med, Opcode::AcceptUniqueIdRange, b, e)
          in .accept_unique_id_range?
            next unless b = message.args[0]?
            next unless e = message.args[1]?
            @free.concat(b...e)
            @on_init.try { |cb| mediate(med, cb) }
          in .register_sensor?
            next unless id = message.args[0]?
            next unless t0 = message.terms[0]?.as?(Term::Str)
            @map[Sensor.new(id, med.sender)] = t0.value
            reply(med, Opcode::InitSensor, id)
            # todo: send Sense(...) with all matching appearance terms
          in .init_sensor?
            next unless id = message.args[0]?
            @used << id
            @on_init_sensor.try { |cb| mediate(med, cb) }
          in .register_appearance?
            next unless id = message.args[0]?
            @appearances[id] = nil
            reply(med, Opcode::InitAppearance, id)
          in .init_appearance?
            next unless id = message.args[0]?
            @used << id
            @on_init_appearance.try { |cb| mediate(med, cb) }
          in .unregister_sensor?
            next unless id = message.args[0]?
            @map.delete(Sensor.new(id, med.sender))
          in .unregister_appearance?
            next unless id = message.args[0]?
            @appearances[id] = nil
          in .set_appearance?
            next unless id = message.args[0]?
            next unless t0 = message.terms[0]?
            next unless @appearances.has_key?(id)
            old = @appearances[id]
            next if old == t0
            @appearances[id] = t0
            @map[t0, Set(Sensor).new].each do |sensor|
              med.reply(sensor.owner, Message[Opcode::Sense, sensor.id, t0])
            end
          in .sense?
            next unless id = message.args[0]?
            next unless term = message.terms[0]?
            @on_sense.try do |cb|
              mediator = Mediator.new(self, med)
              cb.call(term, mediator, @reverse_env[id]?)
            end
          end
        end
      end

      @queue
    end
  end
end
