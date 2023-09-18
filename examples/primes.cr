require "../src/raktor"

include Raktor
include Terms

counter = Node.should do
  sense %Q({ target: "Counter", count < 10_000 })
  tweak do |env|
    Dict[target: Str["Counter"], count: env.as_d.count.as_n + Num[1]]
  end
  show default: Dict[target: Str["Counter"], count: Num[0]]
end

is_prime = Node.should do
  sense %Q({ target: "IsPrime", arg: number } not({ prime: any })) do |env|
    Dict[num: env.as_d.arg, den: Num[2]]
  end

  sense %Q({ target: "IsPrime" } { num: number, den: number })

  tweak(Dict) do |env|
    num = env.num.as_n
    den = env.den.as_n
    Dict[target: Str["IsPrime"], num: num, den: den,
      equal: Boolean[num == den],
      divisible: Boolean[num.div_by?(den).as(Bool)],
    ]
  end

  ag = 0

  show %Q({ num < 2 }), rel: relate(ag, 0) do |ctx|
    Dict[target: Str["IsPrime"], arg: ctx.as_d.num, prime: Boolean[false]]
  end

  show %Q({ equal: true }), rel: relate(ag, 1) do |ctx|
    Dict[target: Str["IsPrime"], arg: ctx.as_d.num, prime: Boolean[true]]
  end

  show %Q({ divisible: true }), rel: relate(ag, 2) do |ctx|
    Dict[target: Str["IsPrime"], arg: ctx.as_d.num, prime: Boolean[false]]
  end

  show(default: Dict[target: Str["IsPrime"], value: Num[123]], rel: relate(ag, 3)) do |env| # feedback
    Dict[target: Str["IsPrime"], num: env.as_d.num, den: env.as_d.den.as_n + Num[1]]
  end
end

counter_to_is_prime_translator = Node.should do
  sense %Q({ target: "Counter", count: number })
  show do |env|
    Dict[target: Str["IsPrime"], arg: env.as_d.count]
  end
end

reader = Node.should do
  sense %Q({ target: "IsPrime", arg: number, prime: true }), &.as_d.arg

  tweak do |n|
    puts n
  end
end

is_prime.join(is_prime)
counter_to_is_prime_translator.join(is_prime)
counter.join(is_prime)
reader.join(is_prime)

sleep
