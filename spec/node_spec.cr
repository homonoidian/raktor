require "./spec_helper"

include Raktor
include Terms

describe Raktor::Node do
  describe "errors" do
    it "should raise at client-side if filter is malformed" do
      host = Node.should { }

      errors = Channel(Exception).new
      c1 = Node.should(errors) do
        sense %Q(")
        sense %Q("foo") { Str["bar"] }
        show
      end

      c1.join(host)

      expect_raises Error, "filter refused: `\"`@0: unterminated string literal" do
        raise errors.receive
      end

      probe(host, 10.milliseconds, "any", Str["foo"]).should eq(Set{Str["foo"], Str["bar"]})
    end
  end

  describe "misc" do
    it "should run addo/subo/divo/mulo" do
      addo = Node.should do
        sense %({ op: "+", a: number, b: number })
        tweak(Dict) { |x| x.a.as_n + x.b.as_n }
        show default: Num[0]
      end

      subo = Node.should do
        sense %({ op: "-", a: number, b: number })
        tweak(Dict) { |x| x.a.as_n - x.b.as_n }
        show default: Num[0]
      end

      mulo = Node.should do
        sense %({ op: "*", a: number, b: number })
        tweak(Dict) { |x| x.a.as_n * x.b.as_n }
        show default: Num[0]
      end

      divo = Node.should do
        sense %({ op: "/", a: number, b: number })
        tweak(Dict) { |x| x.a.as_n / x.b.as_n }
        show default: Num[0]
      end

      addo.join(addo)
      subo.join(addo)
      mulo.join(addo)
      divo.join(addo)

      # Probes below sample the entire world. After the probe is injected
      # into the world, it first samples the current appearances of addo,
      # subo, mulo, and divo, and then changes its appearance to whatever
      # was provided in the arguments to probe. This triggers the appropriate
      # node (addo, subo, mulo or divo) to change is appearance which is
      # then registered as the fifth sample. Hence the five.

      probe(addo, 5, "number", Dict[op: Str["+"], a: Num[100], b: Num[200]]).to_set.should eq(Set{
        Num[0],   # addo
        Num[0],   # subo
        Num[0],   # mulo
        Num[0],   # divo
        Num[300], # addo after change
      })

      probe(addo, 5, "number", Dict[op: Str["-"], a: Num[100], b: Num[200]]).to_set.should eq(Set{
        Num[300],  # addo
        Num[0],    # subo
        Num[0],    # mulo
        Num[0],    # divo
        Num[-100], # subo after change
      })

      probe(addo, 5, "number", Dict[op: Str["*"], a: Num[100], b: Num[200]]).to_set.should eq(Set{
        Num[300],   # addo
        Num[-100],  # subo
        Num[0],     # mulo
        Num[0],     # divo
        Num[20000], # mulo after change
      })

      probe(addo, 5, "number", Dict[op: Str["/"], a: Num[100], b: Num[200]]).to_set.should eq(Set{
        Num[300],   # addo
        Num[-100],  # subo
        Num[20000], # mulo
        Num[0],     # divo
        Num[0.5],   # divo after change
      })

      probe(addo, 5, "number", Dict[op: Str["/"], a: Num[200], b: Num[100]]).to_set.should eq(Set{
        Num[300],   # addo
        Num[-100],  # subo
        Num[20000], # mulo
        Num[0.5],   # divo
        Num[2],     # divo after change
      })

      probe(addo, 4, "number").to_set.should eq(Set{
        Num[300],   # addo
        Num[-100],  # subo
        Num[20000], # mulo
        Num[2],     # divo
      })
    end

    it "should run sum example" do
      sum = Node.should do
        sense %({ request: "+", a: number, b: number })
        tweak Dict do |args|
          # "use" a and b
          args, a = args.without(Str["a"])
          args, b = args.without(Str["b"])
          args.withattr(Str["sum"], a.as(Num) + b.as(Num))
        end
        show
      end

      sum.join(sum)

      q1 = %({ receiver: "probe", sum: number })
      d1 = Dict[receiver: Str["probe"], request: Str["+"], a: Num[100], b: Num[200]]

      q2 = %({ receiver: "probe2", sum: number })
      d2 = Dict[receiver: Str["probe2"], request: Str["+"], a: Num[123], b: Num[456]]

      probe(sum, 10.milliseconds, q1, d1).to_set.should eq(Set{
        Dict[receiver: Str["probe"], request: Str["+"], sum: Num[300]],
      })

      probe(sum, 10.milliseconds, q2, d2).to_set.should eq(Set{
        Dict[receiver: Str["probe2"], request: Str["+"], sum: Num[579]],
      })
    end

    it "should allow a node to connect to multiple servers, keep in sync" do
      s1 = Node.should do
        show "not(any)", default: Dict[s: Str["hello from s1"], index: Num[0]]
      end

      s2 = Node.should do
        show "not(any)", default: Dict[s: Str["hello from s2"], index: Num[1]]
      end

      merger = Node.should do
        sense "{ s: string, index: 0 or 1 }"

        storage = Dict[]

        tweak Dict do |msg|
          storage = storage.withattr(msg.index, msg.s)
          storage
        end

        show "[string, string]"
      end

      s1.join(s1) # we need this for default:
      s2.join(s2) # same

      merger.join(s1)
      merger.join(s2)

      probe(s1, 10.milliseconds, "any").to_set.should eq(Set{
        Dict[s: Str["hello from s1"], index: Num[0]],
        Dict[Str["hello from s1"], Str["hello from s2"]],
      })

      probe(s2, 10.milliseconds, "any").to_set.should eq(Set{
        Dict[s: Str["hello from s2"], index: Num[1]],
        Dict[Str["hello from s1"], Str["hello from s2"]],
      })

      r1 = Node.should do
        show "not(any)", default: Dict[s: Str["hello from random connected 1"], index: Num[0]]
      end

      r2 = Node.should do
        show "not(any)", default: Dict[s: Str["hello from random connected 2"], index: Num[1]]
      end

      r3 = Node.should do
        sense %(["hello from random connected 1", "hello from random connected 2"])
        show { Str["foobra"] }
      end

      r1.join(s2)

      sleep 10.milliseconds

      # I really don't know of a better solution than probing for N milliseconds.
      # Otherwise we have a chance of probing before r1 or merger update,
      # therefore we never know how many terms we'd process. With duration
      # it's a bit more "reliable", but the way all of this works seems
      # shittier and shittier

      probe(s1, 10.milliseconds, "any").to_set.should eq(Set{
        Dict[s: Str["hello from s1"], index: Num[0]],
        Dict[Str["hello from random connected 1"], Str["hello from s2"]],
      })

      probe(s2, 10.milliseconds, "any").to_set.should eq(Set{
        # Dict[Str["hello from s1"], Str["hello from s2"]],
        # the above may appear randomly if we dont sleep (and may sometimes
        # even if we do)
        Dict[s: Str["hello from s2"], index: Num[1]],
        Dict[s: Str["hello from random connected 1"], index: Num[0]],
        Dict[Str["hello from random connected 1"], Str["hello from s2"]],
      })

      r3.join(s1)
      r2.join(s1)

      sleep 10.milliseconds

      probe(s1, 10.milliseconds, "any").to_set.should eq(Set{
        Dict[s: Str["hello from s1"], index: Num[0]],
        Dict[s: Str["hello from random connected 2"], index: Num[1]],
        Str["foobra"],
        Dict[Str["hello from random connected 1"], Str["hello from random connected 2"]],
      })

      probe(s2, 10.milliseconds, "any").to_set.should eq(Set{
        # Dict[Str["hello from s1"], Str["hello from s2"]],
        Dict[s: Str["hello from s2"], index: Num[1]],
        Dict[s: Str["hello from random connected 1"], index: Num[0]],
        Dict[Str["hello from random connected 1"], Str["hello from random connected 2"]],
      })
    end
  end
end
