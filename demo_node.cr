require "./src/usage"
require "http/web_socket"

include Raktor::Protocol

struct RemoteSocket
  include IRemote(Remote)

  def initialize(@ws : HTTP::WebSocket)
  end

  def send(response : Remote)
    @ws.stream do |io|
      response.message.to_cannon_io(io)
    end
  end
end

myself = Chan(Remote).new
spawn do
  used = Set(UInt64).new
  free = Set(UInt64).new
  while req = myself.receive
    msg = req.message
    case msg.opcode
    when .accept_unique_id_range?
      free.concat(msg.args[0]...msg.args[1])
      id0 = free.sample
      free.delete(id0)
      id1 = free.sample
      free.delete(id1)
      id2 = free.sample
      free.delete(id2)
      req.sender.send(Remote.new(myself, Message[Opcode::RegisterSensor, id0, Term::Str.new("/? 10")]))
      req.sender.send(Remote.new(myself, Message[Opcode::RegisterSensor, id1, Term::Str.new("/? 30")]))
      req.sender.send(Remote.new(myself, Message[Opcode::RegisterAppearance, id2]))
    when .init_sensor?
      id = msg.args[0]
      used << id
      puts "init sensor request: #{used}"
    when .init_appearance?
      id = msg.args[0]
      used << id
      puts "Got confirmation of my add appearances request: #{used}"
    when .sense?
      term = msg.terms[0]
      puts "[!] Divisible by 10 or 20 -- #{term}"
    end
  end
end

host = "0.0.0.0"
port = 3000
ws = HTTP::WebSocket.new(URI.parse("ws://#{host}:#{port}"))
remote = RemoteSocket.new(ws)
ws.on_binary do |msg|
  mem = IO::Memory.new(msg, writeable: false)
  myself.send Remote.new(remote, Message.from_cannon_io(mem))
end

ws.run
