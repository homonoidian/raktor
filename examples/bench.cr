# Note that this benchmark is synthetic. You will never have to do so
# many lookups. If you do then you are doing something wrong. For instance
# if you are updating every pixel on every change (roughly the 14ms situation
# in the benchmark below), you could consider giving each pixel a management
# hierarchy. Get a central "director" for the entire screen, then two managers
# for each half, and so on until small groups of individual pixels where it
# is cheap enough to update all of them at once even if only one of them
# should *really* be affected. Then give update commands to the respective
# managers.
#
# There is *obviously* a lot of optimization that I haven't done yet.
# Mostly speaking about compilation here. The runtime uses integer sets
# and integer hashes heavily, so this could be a point where maybe some
# better solution exists. ConjTree looks like and walks like and quacks
# like a trie, factset is basically an intset etc. Something like a vab
# bitarray would be really nice for the fact set specifically; the universe
# is fixed and is limited to the number of used labels (which I think would
# rarely exceed a few million, and that's planning for the future -- right
# now it rarely exceeds a hundred or so); each label can be assigned a bit
# and there we go, getting super fast "inserts", "deletes", and reasonably
# fast iteration. Memory considerations don't worry me too much because we're
# compiling anyway, so we're storing once, not on every lookup. Just thinking...
# All of that could, maybe just maybe, get us closer to the target of sub
# 100ns or so for lookup. But I have always been wrong on estimating the
# result of optimizations, so maybe I'm wrong this time too :) Anyway,
# notably, the current solutions hang most in hashes/sets (judging by the profile).
#
# Ryzen 2200G
#
# Compilation of 200 000 + 1 programs took: 2498.659032ms
#      lookup name age ok  73.35  ( 13.63ms) (± 3.23%)  2.29MB/op   31175.13× slower
#    lookup name age fail   1.67M (599.84ns) (±28.60%)    592B/op       1.37× slower
# lookup name lit age lit   1.27M (787.57ns) (±25.50%)    608B/op       1.80× slower
#        lookup 1 n first   2.27M (439.58ns) (±29.85%)    544B/op       1.01× slower
#         lookup 1 n last   2.29M (437.31ns) (±30.21%)    544B/op            fastest
#                lookup n  10.88  ( 91.88ms) (±17.74%)  51.9MB/op  210109.25× slower

require "benchmark"
require "../src/raktor"

include Raktor

map = Sparse::Map(Int32).new
took = Time.measure do
  map[0...100_000] = (0...100_000).map { %Q({ name string, age /? 10 }) }
  map[100_000...200_000] = (0...100_000).map { |x| %Q({ n #{x} }) }
  map[200_000] = %Q({ name "John Doe", age 23 })
end

puts "Compilation of 200 000 + 1 programs took: #{took.total_milliseconds}ms"

Benchmark.ips do |x|
  x.report("lookup name age ok") do
    dict = Term::Dict[name: Term::Str.new("John Doe"), age: Term::Num.new(30)]
    map[dict]
  end

  x.report("lookup name age fail") do
    dict = Term::Dict[name: Term::Str.new("John Doe"), age: Term::Num.new(45)]
    map[dict]
  end

  x.report("lookup name lit age lit") do
    dict = Term::Dict[name: Term::Str.new("John Doe"), age: Term::Num.new(23)]
    map[dict]
  end

  x.report("lookup 1 n first") do
    map[Term::Dict[n: Term::Num.new(0)]]
  end

  x.report("lookup 1 n last") do
    map[Term::Dict[n: Term::Num.new(100_000 - 1)]]
  end

  x.report("lookup n") do
    (0...100_000).each do |i|
      map[Term::Dict[n: Term::Num.new(i)]]
    end
  end
end
