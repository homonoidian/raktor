module Raktor::Protocol
  enum Opcode : UInt8
    # Initiate connection with a host node. *Sent by a client node to
    # the host node* it wants to connect to. No arguments are required.
    #
    # If everything is alright, the host node will respond with `InitSelf`.
    #
    # The client node must periodically `Ping`, otherwise, the host node
    # will drop the connection. The host node replies to `Ping` messages
    # with `Pong` messages. It is up to the client to decide how to
    # handle them.
    Connect

    # *Sent by a client node to a host node*. Used to confirm connection.
    # If there are no pings for a certain period, the host node will
    # force-disconnect the client node. No arguments are required.
    Ping

    # *Sent by a host node to a client node* in response to `Ping`
    # and `Connect`. No arguments are required.
    Pong

    # *Sent by a host node to a client node* in response to `Connect`.
    # Client nodes may handle this message however they desire. More
    # generally, a client node that receives `InitSelf` is considered to
    # be *acknowledged* by the host and is expected to register its
    # sensors and appearances. `InitSelf` messages have no arguments.
    InitSelf

    # *Sent by a client node to a host node*, usually in response to `InitSelf`.
    # Registers a filter, which is the main part of a node's sensor.
    #
    # ```text
    # RegisterFilter(args: [u64 slot], terms: [string filter])
    # ```
    #
    # *slot* is a client-side reference to the filter. It is used to
    # identify the filter independently from the host(s) the client
    # is connected to. Most notably, *slot* is forwarded in by the host
    # in `InitFilter`, allowing the client to associate its *slot* with
    # a host-specific id.
    #
    # *filter* is the Sparse source code for the filter.
    #
    # If the filter was registered successfully, the host node responds
    # with `InitFilter`. If there was an error, the host node responds
    # with `RefuseFilter`.
    RegisterFilter

    # *Sent by a host node to a client node* in response to a malformed
    # `RegisterFilter`.
    #
    # ```text
    # RefuseFilter(args: [u64 slot], terms: [])
    # ```
    #
    # *slot* is the client-side reference to the filter that was
    # provided in `RegisterFilter`.
    RefuseFilter

    # *Sent by a client node to a host node*, usually in response to `InitSelf`.
    # Registers an appearance.
    #
    # ```text
    # RegisterAppearance(args: [u64 slot], terms: [term? remnant])
    # ```
    #
    # *slot* is a client-side reference to the appearance, similar to
    # that in `RegisterFilter`.
    #
    # *remnant* is an optional argument specifying the term that is
    # shown to nodes after the client disconnects.
    #
    # If the appearance was registered successfully, the host node responds
    # with `InitAppearance`. If there was an error, the host node responds
    # with `RefuseAppearance`.
    RegisterAppearance

    # *Sent by a host node to a client node* in response to a malformed
    # `RegisterAppearance`.
    #
    # ```text
    # RefuseAppearance(args: [u64 slot], terms: [])
    # ```
    #
    # *slot* is the client-side reference to the appearance that was
    # provided in `RegisterAppearance`.
    RefuseAppearance

    # *Sent by a host node to a client node* in response to `RegisterFilter`.
    # If received, it indicates a successful registration of the filter.
    #
    # ```text
    # InitFilter(args: [u64 slot], terms: [string id, term... terms])
    # ```
    #
    # *slot* is the filter slot that was provided by the client node in
    # `RegisterFilter`. See `RegisterFilter` for details.
    #
    # *id* is the freshly minted host-side id of the filter. The client
    # node can use it to refer to the filter when talking with the host
    # node. The host node will use *id* to refer to the filter when
    # talking with the client node.
    #
    # *terms* is the initial set of terms that the filter should react to.
    # When a filter is inserted into the host world it examines all appearances
    # in that world; those matched by the filter are included in `InitFilter`
    # as *terms*.
    InitFilter

    # *Sent by a host node to a client node* in response to `RegisterAppearance`.
    # If received, it indicates a successful registration of the appearance.
    #
    # ```text
    # InitAppearance(args: [u64 slot], terms: [string id])
    # ```
    #
    # *slot* is the appearance slot that was provided by the client node
    # in `RegisterAppearance`. See `RegisterAppearance` for details.
    #
    # *id* is the freshly minted host-side id of the appearance. The
    # client node can use it to refer to the appearance when talking
    # with the host node. The host node will use *id* to refer to the
    # appearance when talking with the client node.
    InitAppearance

    # *Sent by a host node to a client node* in response to appearance
    # change that matches one of the client node's registered filters.
    #
    # ```text
    # Sense(args: [], terms: [any term, string id])
    # ```
    #
    # *term* is the term that the filter matched.
    #
    # *id* is the host-side id of the sensor which the client should
    # have received in `InitSensor`.
    Sense

    # *Sent by a client node to a host node* to trigger an appearance
    # change for one of the client node's appearances.
    #
    # ```
    # SetAppearance(args: [], terms: [any term, string id])
    # ```
    #
    # *term* is the term that should be used as the new appearance.
    #
    # *id* is the host-side id of the appearance which the client should
    # have received in `InitAppearance`.
    SetAppearance

    # Close connection with a host node. Sent by a client node wishing
    # to disconnect. The host node can also forge a Disconnect message
    # and send it to itself if the client times out for some reason.
    # No arguments are required.
    Disconnect

    # TODO
    UnregisterSensor
    # TODO
    UnregisterAppearance

    def to_json(json)
      value.to_json(json)
    end

    def to_cannon_io(io)
      value.to_cannon_io(io)
    end

    def self.new(pull : JSON::PullParser)
      new UInt8.new(pull)
    end

    def self.from_cannon_io(io)
      new UInt8.from_cannon_io(io)
    end
  end

  # Includers can be senders and receivers of `Parcel`s.
  #
  # Includers *MUST* be hashable, their hashes&equality *MUST NOT*
  # mutate. Endpoints are used extensively as keys in hashes/sets.
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
    include JSON::Serializable

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
