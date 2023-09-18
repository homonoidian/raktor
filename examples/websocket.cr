require "http"
require "../peer"

include Raktor
include Terms

# In this very basic example we have three nodes.
#
# One (display) is used as a host (just about any node can be used as a
# host; you can also provide a remote address of the host node as you
# can see from the else clause, to connect a client node to it). Note
# how display is not only the host, but also a client of itself.
#
# The host node (display) is bound to the user-provided URI. Binding
# means a whole new [web?] [socket] server is created that deserializes
# + redirects the incoming messages to the actual host node, which is
# running on a separate Fiber.
#
# The second node, host counter, is another Fiber (quite possibly another
# thread), and it connects to display (our host) locally. That's two fibers
# (and possibly threads) talking to each other, display and host_counter.
#
# The third node, from the else clause, is a simple feedback counter that
# joins a remote host which the user should have provided in the args.
#
# So display "leases" itself as a world-space, host_counter and counter
# and the client side of display join the world-space, and start talking &
# watching each other. Just as in the clockwork/microbe analogy, we have
# a "bag" of things that can trigger each other without knowing about
# each other, only following the protocol that mother nature designed
# (in our case the programmer plays the role of the nature)
#
# OF COURSE this is unsafe in the security sense of the word, because any
# node can spy on all communication by sensing "any". But that's kind of
# the point. I believe protection should be situated at world-edges
# (connections between worlds), not inside worlds.
#
# See, it would be dumb to forbid a bacteria's internals from knowing
# about the comms that happen inside it; why the hell shouldn't a ribosome
# know about some protein flowing by? Being able to hook in to just about
# any process immediately is a handy feature for both mother nature and
# programmers.
#
# On the other hand, the internals of two bacteria are physically
# separate (the world edge I'm talking about), so we might say one
# is "secure" from the other; the "body" of the edge though is formed
# from the messages the two bacteria are exchanging via the outside
# environment; the membrane provides all the security a cell ever
# requires, and if invaders do come inside the cell is basically
# defenseless (we can observe this with viruses). Probably the only
# way it can save itself is by doing its "bookkeeping" and "functioning"
# using protocols unknown to/incompatible with the virus, therefore,
# the virus would not be able to make sense of the talk that it's surrounded
# by and won't be able to "ask" anyone or anything to replicate itself.

# Use one node as a "display" for another node's result, in our case
# the other node is going to be a counter.

if ARGV.empty?
  abort "usage: websocket [host] <uri>"
end

if ARGV[0] == "host"
  display = Node.should do
    sense %({ op: "display", arg: any }), &.as_d.arg
    tweak { |arg| puts arg }
  end

  host_counter = Node.should do
    sense %({ op: "count", count: number }), &.as_d.count
    tweak { |arg| Str["Can perceive count host-side, it is: #{arg}"] }
    show { |s| Dict[op: Str["display"], arg: s] }
  end

  display.join(display)
  host_counter.join(display)

  display.bind(URI.parse(ARGV[1]))
else
  counter = Node.should do
    sense %({ op: "count", count: number }), &.as_d.count
    tweak(Num, &.succ)
    show { |n| Dict[op: Str["display"], arg: n] }
    show { |n| Dict[op: Str["count"], count: n] }
    show "not(any)", default: Dict[op: Str["count"], count: Num[0]]
  end
  counter.join(URI.parse(ARGV[0]))
end

sleep
