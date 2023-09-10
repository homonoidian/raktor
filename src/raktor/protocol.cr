require "cannon"

module Raktor::Protocol
  module IParcel
    abstract def reply(id : UInt64, message : Message)
    abstract def sender : UInt64
    abstract def receiver : UInt64
    abstract def message : Message
  end

  module IRouter(T)
    abstract def assign(id : UInt64, object : T)
    abstract def drop(id : UInt64)
    abstract def send(sender : UInt64, receiver : UInt64, message : Message)
  end

  module IEndpoint(T)
    abstract def send(object : T)
  end

  alias IParcelEndpoint = IEndpoint(IParcel)

  record RouterParcel(T), router : IRouter(T), sender : UInt64, receiver : UInt64, message : Message do
    include IParcel

    def reply(id : UInt64, message : Message)
      router.send(receiver, id, message)
    end
  end

  module IHashParcelRouter(T)
    include IRouter(IParcelEndpoint)

    def initialize
      @hash = {} of UInt64 => IParcelEndpoint
    end

    abstract def map(object : T) : UInt64

    def assign(id : UInt64, object : IParcelEndpoint)
      @hash[id] = object
    end

    def drop(id : UInt64)
      @hash.delete(id)
    end

    def send(sender : UInt64, receiver : UInt64, message : Message)
      return unless endpoint = @hash[receiver]?

      endpoint.send RouterParcel.new(self, sender, receiver, message)
    end

    def assign(id : T, object : IParcelEndpoint)
      assign(map(id), object)
    end

    def drop(id : T)
      drop(map(id))
    end

    def send(sender : T, receiver : T, message : Message)
      send(map(sender), map(receiver), message)
    end
  end

  struct ParcelEndpointRouter
    include IHashParcelRouter(UInt64)

    def map(object : UInt64) : UInt64
      object
    end
  end

  struct NamedParcelEndpointRouter
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
    RegisterSensor
    RegisterAppearance

    UnregisterSensor
    UnregisterAppearance

    SetAppearance

    RequestUniqueIdRange
    AcceptUniqueIdRange

    InitSensor
    InitAppearance

    Sense

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
