require "./spec_helper"

include Raktor
include Terms

describe Raktor::Node do
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

      probe(addo, 5, "number", Dict[op: Str["+"], a: Num[100], b: Num[200]]).should eq([
        Num[0],   # addo
        Num[0],   # subo
        Num[0],   # mulo
        Num[0],   # divo
        Num[300], # addo after change
      ])

      probe(addo, 5, "number", Dict[op: Str["-"], a: Num[100], b: Num[200]]).should eq([
        Num[300],  # addo
        Num[0],    # subo
        Num[0],    # mulo
        Num[0],    # divo
        Num[-100], # subo after change
      ])

      probe(addo, 5, "number", Dict[op: Str["*"], a: Num[100], b: Num[200]]).should eq([
        Num[300],   # addo
        Num[-100],  # subo
        Num[0],     # mulo
        Num[0],     # divo
        Num[20000], # mulo after change
      ])

      probe(addo, 5, "number", Dict[op: Str["/"], a: Num[100], b: Num[200]]).should eq([
        Num[300],   # addo
        Num[-100],  # subo
        Num[20000], # mulo
        Num[0],     # divo
        Num[0.5],   # divo after change
      ])

      probe(addo, 5, "number", Dict[op: Str["/"], a: Num[200], b: Num[100]]).should eq([
        Num[300],   # addo
        Num[-100],  # subo
        Num[20000], # mulo
        Num[0.5],   # divo
        Num[2],     # divo after change
      ])

      probe(addo, 4, "number").should eq([
        Num[300],   # addo
        Num[-100],  # subo
        Num[20000], # mulo
        Num[2],     # divo
      ])
    end
  end
end
