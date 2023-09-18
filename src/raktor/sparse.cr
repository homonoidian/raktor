require "./sparse/util"
require "./sparse/mapping"
require "./sparse/lex"
require "./sparse/ast"
require "./sparse/parse"
require "./sparse/machine"
require "./sparse/gate"
require "./sparse/chain"
require "./sparse/filter"
require "./sparse/label"
require "./sparse/label_set"
require "./sparse/rule"
require "./sparse/subst"
require "./sparse/rewriters"
require "./sparse/rule_book"
require "./sparse/chunk"
require "./sparse/compiler"
require "./sparse/fact_set"
require "./sparse/conj_tree"
require "./sparse/map"

# Sparse ("Sensor PARSE") is a declarative language that is used to
# define sensors. The language is exposed to the outside world through
# a hash table-like interface, `Sparse::Map`, which should be treated
# as a black box.
#
# ```
# map = Sparse::Map(Int32).new
# map[0] = "/? 10"
# map[1] = "/? 20"
#
# map[Term::Str.new("foo")] # => []
# map[Term::Num.new(123)]   # => []
# map[Term::Num.new(30)]    # => [1]
# map[Term::Num.new(100)]   # => [0, 1]
# ```
module Raktor::Sparse
end
