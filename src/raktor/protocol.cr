module Raktor::Protocol
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

  # Includers can be senders and receivers of `Parcel`s.
  module IParcelEndpoint
    # Processes and optionally replies to the given *parcel*.
    abstract def receive(parcel : Parcel)

    # Disconnects this endpoint from another *endpoint*.
    def disconnect(endpoint : IParcelEndpoint)
    end

    # Sends the given *message* to *other*.
    def send(other : IParcelEndpoint, message : Message)
      other.receive Parcel.new(self, other, message)
    end
  end

  # A parcel is a `Message` with an associated `Link`, representing the
  # sender-receiver connection that was used during transmission.
  struct Parcel
    # Returns the associated link.
    getter link

    # Returns the message.
    getter message

    def initialize(@link : Link, @message : Message)
    end

    def initialize(sender : IParcelEndpoint, receiver : IParcelEndpoint, message : Message)
      initialize(Link.new(sender, receiver), message)
    end

    # See the same method in `Link`.
    delegate :reply, :sender, :receiver, to: @link

    def to_s(io)
      io << "Parcel<link=" << @link << ": " << @message << ">"
    end

    def_equals_and_hash @link, @message
  end

  # A link between two `IParcelEndpoint`s.
  struct Link
    # Returns the sender ("from") endpoint of this link.
    getter sender

    # Returns the receiver ("to") endpoint of this link.
    getter receiver

    def initialize(@sender : IParcelEndpoint, @receiver : IParcelEndpoint)
    end

    # Receiver replies *other* with *message*.
    def reply(other : IParcelEndpoint, message : Message)
      other.receive Parcel.new(@receiver, other, message)
    end

    # Receiver replies sender with *message*.
    def reply(message : Message)
      reply(@sender, message)
    end

    # Sender replies receiver with *message*.
    def reuse(message : Message)
      @receiver.receive Parcel.new(@sender, @receiver, message)
    end

    # Breaks the link between the receiver and the sender.
    def break
      @receiver.disconnect(@sender)
    end

    def to_s(io)
      io << "<Link sender=" << @sender << ", receiver=" << @receiver << ">"
    end

    def_equals_and_hash @sender, @receiver
  end

  # Represents a message. `IParcelEndpoint`s use messages to communicate
  # with each other (and sometimes with themselves), both over the network
  # and between fibers. Messages are serializable using `Cannon`.
  record Message, opcode : Opcode, args = [] of UInt64, terms = [] of Term do
    include Cannon::Auto

    # A faster way to create `Message`s.
    #
    # ```
    # Message[Opcode::Connect]
    # Message[Opcode::InitAppearance, 0, Str["hello"]]
    # # ...
    # ```
    def self.[](opcode : Opcode, args : Enumerable(UInt64 | Term)? = nil)
      return new(opcode) unless args

      new(opcode, args: [*args.select(UInt64)], terms: [*args.select(Term)])
    end

    # :ditto:
    def self.[](opcode : Opcode, *args : UInt64 | Term)
      self[opcode, args]
    end

    def to_s(io)
      io << opcode << "[" << args.join(", ") << ":" << terms.join(", ") << "]"
    end
  end
end
