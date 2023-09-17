require "cannon"

module Raktor::Protocol
  module IParcel
    abstract def reply(id : UInt64, message : Message)
    abstract def sender : UInt64
    abstract def receiver : UInt64
    abstract def message : Message
    abstract def disconnect

    def reply(message : Message)
      reply(sender, message)
    end

    def_equals_and_hash sender, receiver, message
  end

  module IRouter(T)
    # abstract def assign(id : UInt64, object : T)
    # abstract def drop(id : UInt64)
    abstract def send(sender : UInt64, receiver : UInt64, message : Message)
    abstract def disconnect(id : UInt64)

    def connect(sender, receiver)
      send(sender, receiver, Message[Opcode::Connect])
    end
  end

  module IEndpoint(T)
    abstract def send(object : T)

    def disconnect
    end
  end

  alias IParcelEndpoint = IEndpoint(IParcel)

  record RouterParcel(T), router : IRouter(T), sender : UInt64, receiver : UInt64, message : Message do
    include IParcel

    def reply(id : UInt64, message : Message)
      router.send(receiver, id, message)
    end

    def disconnect
      router.disconnect(sender)
    end
  end

  module IHashParcelRouter(T)
    include IRouter(IParcelEndpoint)

    def initialize
      @routes = {} of UInt64 => IParcelEndpoint
    end

    abstract def map(object : T) : UInt64

    def assign(id : UInt64, object : IParcelEndpoint)
      @routes[id] = object
    end

    def drop(id : UInt64)
      @routes.delete(id)
    end

    def disconnect(id : UInt64)
      return unless endpoint = @routes[id]?

      endpoint.disconnect
      drop(id)
    end

    def send(sender : UInt64, receiver : UInt64, message : Message)
      return unless endpoint = @routes[receiver]?

      endpoint.send RouterParcel.new(self, sender, receiver, message)
    end

    def assign(id : T, object : IParcelEndpoint)
      assign(map(id), object)
    end

    def drop(id : T)
      drop(map(id))
    end

    def disconnect(id : T)
      disconnect(map(id))
    end

    def send(sender : T, receiver : T, message : Message)
      send(map(sender), map(receiver), message)
    end
  end

  class ParcelEndpointRouter
    include IHashParcelRouter(UInt64)

    def map(object : UInt64) : UInt64
      object
    end
  end

  class NamedParcelEndpointRouter
    include IHashParcelRouter(Symbol)

    @env = {} of Symbol => UInt64
    @counter = 0u64

    def genint
      @counter, _ = @counter + 1, @counter
    end

    def map(object : Symbol) : UInt64
      @env[object] ||= genint
    end
  end

  enum Opcode : UInt8
    Connect
    Disconnect

    RegisterSensor
    RegisterAppearance

    UnregisterSensor
    UnregisterAppearance

    SetAppearance

    RequestUniqueIdRange
    AcceptUniqueIdRange

    InitSelf
    InitSensor
    InitAppearance

    Sense

    Ping
    Pong

    def to_cannon_io(io)
      value.to_cannon_io(io)
    end

    def self.from_cannon_io(io)
      Opcode.new(UInt8.from_cannon_io(io))
    end
  end

  record Message, opcode : Opcode, args = [] of UInt64, terms = [] of Term do
    include Cannon::Auto

    def self.[](opcode : Opcode, args : Enumerable(UInt64 | Term)? = nil)
      return new(opcode) unless args

      new(opcode, args: [*args.select(UInt64)], terms: [*args.select(Term)])
    end

    def self.[](opcode : Opcode, *args : UInt64 | Term)
      self[opcode, args]
    end
  end
end
