module Raktor
  FormatLog = ::Log.for("format")

  # Lists the supported serialization formats, provides `send` and `receive`
  # methods that can be used to serialize/deserialize before forwarding
  # messages to the receiver.
  enum Format
    # Serialize using a binary format. Faster to encode/decode but usable
    # only if both the sender and the receiver are Crystal/Raktor nodes.
    Binary

    # Serialize using JSON. Slower to encode/decode but can be used with
    # clients other than Crystal/Raktor.
    #
    # To become a Raktor client the receiver must adhere to the fairly-
    # lightweight client protocol (see `Node::Role::Client`). Moreover,
    # the initiative is on the side of the client. So in Raktor, it is
    # the clients that decide how much of the protocol to follow.
    #
    # For example, a JavaScript client could display the results of work
    # done by a Python client, while routing (serving) between them is
    # done by a Crystal/Raktor node.
    JSON

    # Calls *callback* with deserialized messages from *socket*.
    def receive(socket : HTTP::WebSocket, &callback : Message ->)
      case self
      in .binary?
        socket.on_binary do |binary|
          io = IO::Memory.new(binary)
          callback.call Message.from_cannon_io(io)
        end
      in .json?
        socket.on_message do |message|
          callback.call Message.from_json(message)
        end
      end
    end

    # Serializes *message* and sends it to the given *socket*.
    def send(socket : HTTP::WebSocket, message : Message)
      case self
      in .binary? then socket.stream { |io| message.to_cannon_io(io) }
      in .json?
        json = message.to_json
        FormatLog.trace { "serialized to #{json}" } # TODO: remove this once JSON protocol is documented?
        socket.send(json)
      end
    end
  end
end
