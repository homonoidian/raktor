module Raktor
  struct Chan(T)
    include Protocol::IEndpoint(T)

    def initialize
      @queue = Disruptor::Queue(T).new(4096, Disruptor::WaitWithSpin.new)
    end

    def send(object : T)
      @queue.push(object)
    end

    def receive : T
      @queue.pop
    end
  end

  class MapServer
    include Protocol

    struct Mediator
      def initialize(@parcel : IParcel)
      end

      def sense(id : UInt64, program : String)
        @parcel.reply(@parcel.sender, Message[Opcode::RegisterSensor, id, Term::Str.new(program)])
      end

      def appearance(id : UInt64)
        @parcel.reply(@parcel.sender, Message[Opcode::RegisterAppearance, id])
      end

      def appear(id : UInt64, term : Term)
        @parcel.reply(@parcel.sender, Message[Opcode::SetAppearance, id, term])
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

    def on_sense(&@on_sense : Term, Mediator, UInt64 ->)
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
            next unless e = message.args[0]?
            @free.concat(b...e)
            @on_init.try do |cb|
              mediator = Mediator.new(med)
              cb.call(mediator)
            end
          in .register_sensor?
            next unless id = message.args[0]?
            next unless t0 = message.terms[0]?.as?(Term::Str)
            @map[Sensor.new(id, med.sender)] = t0.value
            reply(med, Opcode::InitSensor, id)
            # todo: send Sense(...) with all matching appearance terms
          in .init_sensor?
            next unless id = message.args[0]?
            @used << id
            @on_init_sensor.try do |cb|
              mediator = Mediator.new(med)
              cb.call(mediator)
            end
          in .register_appearance?
            next unless id = message.args[0]?
            @appearances[id] = nil
            reply(med, Opcode::InitAppearance, id)
          in .init_appearance?
            next unless id = message.args[0]?
            @used << id
            @on_init_appearance.try do |cb|
              mediator = Mediator.new(med)
              cb.call(mediator)
            end
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
              mediator = Mediator.new(med)
              cb.call(term, mediator, id)
            end
          end
        end
      end

      @queue
    end
  end
end
