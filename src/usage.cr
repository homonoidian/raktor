require "disruptor"
require "./raktor"

include Raktor

# World : manages a sparse map, list of sensors
# list of appearances.
#
# World accepts commands: add sensor, add appearance,
# send message, remove sensor, remove appearance, change
# sensor, change appearance
#
# ReceiverAdd(id, program) => success | failure
# ReceiverDel(id) => success | failure
#
# Blit(term)
#
# AllocaId() => batch of 1024 ids

module Raktor
  struct Chan(T)
    include Protocol::IRemote(T)

    def initialize
      @queue = Disruptor::Queue(T).new(4096, Disruptor::WaitWithYield.new)
    end

    def send(response : T)
      @queue.push(response)
    end

    def receive : T
      @queue.pop
    end
  end

  class Server
    include Protocol

    ID_BATCH_SIZE = 1024

    record Sensor, id : UInt64, owner : IRemote(Remote) do
      def_equals_and_hash id
    end

    def initialize
      @map = Sparse::Map(Sensor).new
      @appearances = {} of UInt64 => Term?
      @queue = Chan(Remote).new
      @counter = 0u64
    end

    def spawn
      spawn do
        while req = @queue.receive
          msg = req.message
          case msg.opcode
          when .request_unique_id_range?
            b = @counter
            e = @counter += ID_BATCH_SIZE
            req.sender.send(Remote.new(@queue, Message[Opcode::AcceptUniqueIdRange, b, e]))
          when .register_sensor?
            id = msg.args[0]
            program = msg.terms[0].as(Term::Str).value
            @map[Sensor.new(id, req.sender)] = program
            req.sender.send(Remote.new(@queue, Message[Opcode::InitSensor, id]))
            # todo: send Changed(...) with all matching appearance terms
          when .register_appearance?
            id = msg.args[0]
            @appearances[id] = nil
            req.sender.send(Remote.new(@queue, Message[Opcode::InitAppearance, id]))
          when .set_appearance?
            id = msg.args[0]
            term = msg.terms[0]
            next unless @appearances.has_key?(id)
            old = @appearances[id]
            next if old == term
            @appearances[id] = term
            @map[term, Set(Sensor).new].each do |sensor|
              sensor.owner.send(Remote.new(@queue, Message[Opcode::Sense, sensor.id, term]))
            end
          end
        end
      end

      @queue
    end
  end
end
