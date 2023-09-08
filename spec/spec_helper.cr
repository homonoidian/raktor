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

def mq(map : Sparse::Map(T), term : Term, matches : Enumerable(Int32)) forall T
  map[term, Set(Int32).new].should eq(matches.to_set)
end

def mq(map : Sparse::Map(T), term : Term, *matches : Int32) forall T
  mq(map, term, Set{*matches})
end

def mq(map : Sparse::Map(T), term : Term) forall T
  mq(map, term, Set(Int32).new)
end
