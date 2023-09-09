# Raktor

TL;DR WIP

Reactive A~~C~~KTOR

The following is mostly a list of plans, written in present tense because I don't know English :) This project is in only at the very first stages.
It has no public interface yet. But it does seem promising.

* Raktor is inspired by my speculations about how the brain works, and by my understanding
  of OOP, actor oriented stuff etc. It's also inspired by my previous experiment [Synapse](https://github.com/homonoidian/synapse).

* Raktor throws away the notion of pointers. Messages *are* pointers. The object graph is
  determined by what the objects are talking about at *this* moment, not by programmer's
  choice ahead of time. This makes insertion of new moving parts into the system a breeze
  (at least it should...). And it forces the progammer to think in a way that makes this
  possible.

* Raktor nodes (that's how objects are called in Raktor) have *sensors* and *appearances*. Raktor
  nodes live in a *world*. It is the world's primary objective to map sensors to appearances
  (to connect "objects" with "pointers"). When a node's appearance changes, a sensor that is
  configured to sense that *kind* of appearance senses it, and lets the node react, in turn the
  node may change its appearance and so on. Feedback is allowed, of course, because I love feedback!
  Nodes can react to their own appearance changing.

* Nodes can be different threads, different computers etc. The world can be put on a server,
  so that client nodes reach to the server to communicate. The general approach I call *the world pattern*,
  where all comms of entities is managed by an object called the *world*. Raktor implements the world
  pattern. Regarding the network, of course there is a huge trade-off, and I don't know yet what's the
  best way to get something in between. Transmission over network (even localhost/UNIX socket) is vastly
  slower than threads, threads are slower than fibers, and fibers are slower than sequ -- context switch wise
  etc. So even though the runtime can crunch 100s of thousands of messages per second, the way transmission
  is implemented may reduce the number to mere 100s or 10s (*not* thousands, just 100s or 10s) per second.

* A node consists of *sensors*, *appearances*, and the kernel. Sensors sense different things in
  the world. Appearances expose the same value produced by the kernel in different ways. Sensors
  consist of a *filter head* and a *mapper*. A sensor's filter head is looking toward the world.
  Appearances consist of a filter head and a mapper. An appearance's filter head is looking toward
  the kernel. The flow is as follows: `world -> sensor filter head -> mapper -> kernel -> appearance filter head -> appearance mapper -> world`.

* The kernel is a pure function of the form `x -> x'`.

* Sensors *sense* and make sensor-domain union kernel-domain -specific decisions in their *mapper*,
  effectively they translate the data they sense to node kernel's domain so that the kernel can do
  something about the sensed data. You can imagine node kernels as little instances of Redux (if you
  know React etc. kernel would be easier to understand I suppose).

* Appearances choose which kernel decisions can be "enacted" with their respective filter heads,
  and "enact" them using their mapper. This way, appearances are also domain-specific. For instance,
  the same node can have a "sound" appearance and a "visual" appearance, upon which other nodes react.
  For instance a display node living in the same world may perceive the visual appearance and a speaker
  node may perceive the sound appearance.

To summarize: node kernels are state reducers, sensors map domain-specific *changes* to new node states,
appearances look at changes in their node's state and map that to domain-specific *actions*.

There is a lot more to discover. But for now I'd like a basic setup to try things out. That's what this repo is.

E.g. `mouse coordinate -> x y -> makeCircle(x, y, radius=20) -> allpass -> getPointsInCircle(circle) -> world`. Note how easy
it becomes to add domain-specific sensors (e.g. listen to nodes tracking keypresses as well as mouse coordinates) without
touching the kernel. Similarly, it becomes easy to add new domain-specific appearances (and filter values "out of the domain's range"
using the appearance filter head).

All of this is very similar to observer/observable aka reactivity aka reactive streams, except that you don't
have to do any kind of subscribing by hand. How your objects communicate determines who is "subscribed" to whom
(note that the system does no *actual* subscribing under the hood; you as the programmer should think of the system
as a mass-notifier; it notifies *everyone* of the change. Of course it doesn't do that because that would be too
inefficient, but please please think about it this way. Otherwise I don't think it's possible to *get* the system)

## Installation

TODO: Write installation instructions here

## Usage

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/homonoidian/raktor/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Alexey Yurchenko](https://github.com/homonoidian) - creator and maintainer
