require "cannon"

module Raktor::Protocol
  module IParcelEndpoint
    abstract def receive(parcel : Parcel)

    def send(receiver : IParcelEndpoint, message : Message)
      receiver.receive Parcel.new(self, receiver, message)
    end

    def disconnect
    end
  end

  record Parcel, sender : IParcelEndpoint, receiver : IParcelEndpoint, message : Message do
    def reply(other : IParcelEndpoint, message : Message)
      other.receive Parcel.new(receiver, other, message)
    end

    def reply(message : Message)
      reply(sender, message)
    end

    def disconnect
      receiver.disconnect
    end

    def to_s(io)
      io << "Parcel<sender=" << sender << ", receiver=" << receiver << ": " << message << ">"
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

    def to_s(io)
      io << opcode << "[" << args.join(", ") << ":" << terms.join(", ") << "]"
    end
  end
end
