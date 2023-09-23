require "spec"
require "../src/raktor"

def q(query : String, term : Term, matches : Enumerable(Int32))
  map = Sparse::Map(Int32).new
  parts = query.split(";", remove_empty: true)
  map[0...parts.size] = parts
  mq(map, term, matches)
end

def q(query : String, term : Term, *matches : Int32)
  q(query, term, Set{*matches})
end

def q(query : String, term : Term)
  q(query, term, Set(Int32).new)
end

def mq(map : Sparse::Map(T) | Sparse::Map::UpsertQuery(T), term : Term, matches : Enumerable(Int32)) forall T
  map[term, Set(Int32).new].should eq(matches.to_set)
end

def mq(map : Sparse::Map(T) | Sparse::Map::UpsertQuery(T), term : Term, *matches : Int32) forall T
  mq(map, term, Set{*matches})
end

def mq(map : Sparse::Map(T) | Sparse::Map::UpsertQuery(T), term : Term) forall T
  mq(map, term, Set(Int32).new)
end

def probe(host, nsamples : Int32, filter : String, default : Term? = nil, remnant : Term? = nil)
  samples = Channel(Term).new

  probe = Node.should do
    sense filter

    sent = 0

    tweak do |it, ctrl|
      samples.send(it)
      sent += 1
      if sent == nsamples
        ctrl.disconnect
      end
      it
    end

    show "not(any)", default: default, remnant: remnant
  end

  probe.join(host)

  (0...nsamples).map { samples.receive }
end

def probe(host, duration : Time::Span, filter : String, default : Term? = nil, remnant : Term? = nil)
  samples = Channel(Term).new

  probe = Node.should do
    sense filter

    tweak do |it|
      samples.send(it)
      it
    end

    show "not(any)", default: default, remnant: remnant
  end

  probe.join(host)

  terms = Set(Term).new
  while true
    select
    when sample = samples.receive
      terms << sample
    when timeout(duration)
      probe.send(host, Message[Opcode::Disconnect])
      break
    end
  end

  terms
end
