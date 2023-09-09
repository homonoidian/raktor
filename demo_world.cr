require "./src/usage"
require "http/web_socket"

include Raktor::Protocol

struct RemoteSocket
  include IRemote(Remote)

  def initialize(@ws : HTTP::WebSocket)
  end

  def send(response : Remote)
    puts "SEND #{response.message}"
    @ws.stream do |io|
      response.message.to_cannon_io(io)
    end
  end
end

world = Raktor::Server.new
myself = world.spawn

SOCKETS = [] of HTTP::WebSocket
ws_handler = HTTP::WebSocketHandler.new do |socket|
  client = RemoteSocket.new(socket)
  SOCKETS << socket
  myself.send(Remote.new(client, Message[Opcode::RequestUniqueIdRange]))
  socket.on_binary do |msg|
    mem = IO::Memory.new(msg, writeable: false)
    decoded = Message.from_cannon_io(mem)
    puts "ACCEPT #{decoded}"
    myself.send Remote.new(client, decoded)
  end
  socket.on_close do
    SOCKETS.delete(socket)
  end
end
server = HTTP::Server.new([ws_handler])
address = server.bind_tcp "0.0.0.0", 3000
puts "Listening on #{address}"
server.listen
