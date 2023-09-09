require "cannon"

module Raktor::Protocol
  module IRemote(T)
    abstract def send(response : T)
  end

  record Remote, sender : IRemote(Remote), message : Message

  enum Opcode : UInt8
    RegisterSensor
    RegisterAppearance
    SetAppearance
    RequestUniqueIdRange

    InitSensor
    InitAppearance
    Sense
    AcceptUniqueIdRange

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
