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

myself = Chan(Remote).new

spawn do
  used = Set(UInt64).new
  free = Set(UInt64).new
  symtab = {} of Symbol => UInt64
  symtab_staging = {} of UInt64 => Symbol
  while req = myself.receive
    msg = req.message
    case msg.opcode
    when .accept_unique_id_range?
      puts "accept id range"
      free.concat(msg.args[0]...msg.args[1])
      id0 = free.sample
      free.delete(id0)
      id1 = free.sample
      free.delete(id1)
      symtab_staging[id1] = :counter
      req.sender.send(Remote.new(myself, Message[Opcode::RegisterSensor, id0, Term::Str.new(%Q(number))]))
      req.sender.send(Remote.new(myself, Message[Opcode::RegisterAppearance, id1]))
    when .init_sensor?
      id = msg.args[0]
      used << id
      puts "init sensor -- success"
    when .init_appearance?
      id = msg.args[0]
      used << id
      symtab[symtab_staging[id]] = id
      symtab_staging.delete(id)
      puts "init appearance -- success"
      req.sender.send(Remote.new(myself, Message[Opcode::SetAppearance, symtab[:counter], Term::Num.new(0)]))
    when .sense?
      count = msg.terms[0].as(Term::Num).value
      req.sender.send(Remote.new(myself, Message[Opcode::SetAppearance, symtab[:counter], Term::Num.new(count + 1)]))
    end
  end
end

host = "0.0.0.0"
port = 3000
ws = HTTP::WebSocket.new(URI.parse("ws://#{host}:#{port}"))
remote = RemoteSocket.new(ws)
ws.on_binary do |msg|
  mem = IO::Memory.new(msg, writeable: false)
  decoded = Message.from_cannon_io(mem)
  puts "ACCEPT #{decoded}"
  myself.send Remote.new(remote, decoded)
end

ws.run
