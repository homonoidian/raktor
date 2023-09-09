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
# Ryzen 2200G
#
# Compilation of 200 000 + 1 programs took: 2537.831687ms
#      lookup name age ok  70.90  ( 14.10ms) (± 3.48%)  2.29MB/op   24453.37× slower
#    lookup name age fail   1.73M (576.76ns) (±29.90%)    592B/op            fastest
# lookup name lit age lit   1.33M (753.17ns) (±26.85%)    608B/op       1.31× slower
#                lookup n  10.70  ( 93.44ms) (±18.32%)  51.9MB/op  162005.04× slower

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

  x.report("lookup n") do
    (0...100_000).each do |i|
      map[Term::Dict[n: Term::Num.new(i)]]
    end
  end
end
