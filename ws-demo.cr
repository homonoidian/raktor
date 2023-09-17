require "./peer"
require "http"
require "http/web_socket"

include Raktor
include Terms

struct WsEndpoint
  include IParcelEndpoint

  def initialize(@ws : HTTP::WebSocket)
  end

  def send(object : IParcel)
    puts "Streaming message #{object.message}"
    # I am the receiver. Send to web socket
    @ws.stream do |io|
      object.message.to_cannon_io(io)
    end
  rescue IO::Error
  end

  def disconnect
    @ws.close
  end
end


# Server
def server_mode(uri, node)
  counter = 0u64

  host = counter
  counter += 1

  router = ParcelEndpointRouter.new
  router.assign(host, node.inbox)
  router.connect(host, host)

  ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
    client = counter
    counter += 1

    router.assign(client, WsEndpoint.new(ws))

    ws.on_binary do |binary|
      io = IO::Memory.new(binary)
      msg = Message.from_cannon_io(io)
      puts "Received #{msg} from #{client}"
      router.send(client, host, msg)
    end
  end

  server = HTTP::Server.new [ws_handler]

  puts "Listening to connections on #{uri}..."

  server.bind URI.parse(uri)
  server.listen
end

# Client
def client_mode(uri, node)
  # Open websocket connection
  ws = HTTP::WebSocket.new(URI.parse(uri))

  counter = 0u64

  host = counter
  counter += 1

  router = ParcelEndpointRouter.new
  router.assign(host, WsEndpoint.new(ws))

  client = counter
  router.assign(client, node.inbox)
  router.connect(client, host)
  counter += 1

  # Set callback
  ws.on_binary do |binary|
    io = IO::Memory.new(binary)
    msg = Message.from_cannon_io(io)
    puts "Received #{msg} from #{host}"
    router.send(host, client, msg)
  end

  ws.on_close do
    puts "Received CLOSE from ##{host}"
  end

  # Start infinite loop
  ws.run
end

if ARGV.empty?
  abort "usage: ws-demo [s] url"
end

# uni = Universe.new

# uni.spawn(node1) # local server
# uni.spawn(node2, on: "tcp://0.0.0.0:5000") # local, expose
# uni.spawn(uri)   # client, network
# uni.spawn(uri)   # server, network
# uni.spawn(uri)   # client, network

# uni.kill(node1)
# uni.kill(node2)
# uni.kill(ws1)
# uni.kill(ws2)
# uni.kill(ws3)



if server = ARGV[0] == "s"
  node1 = Node.should do
    sense %({ op: "display", val: string })
    tweak(Dict) do |d|
      puts d.val
      d
    end
  end

  node2 = Node.should do
    sense %({ subj: "counter", count: number })
    tweak(Dict) do |d|
      puts "Got counter server-side, on another fiber: #{d}"
      d
    end
  end

  server_mode(ARGV[1], node1)
else
  node = Node.should do
    sense %({ subj: "counter", count: number }), &.as_d.count
    tweak(Num) do |n|
      n + Num[1]
    end
    show do |n|
      Dict[subj: Str["counter"], count: n]
    end
    show do |n|
      Dict[op: Str["display"], val: Str[n.value]]
    end
    show "not(any)", default: Dict[subj: Str["counter"], count: Num[0]]
  end

  client_mode(ARGV[0], node)
end
