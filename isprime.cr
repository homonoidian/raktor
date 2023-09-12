require "big"

# https://github.com/kuende/miller_rabin
module MillerRabin
  def self.pow(n : UInt64, count : UInt64, mod : UInt64) : UInt64
    number = 1_u64
    while count > 0
      if count % 2 == 1
        number = ((BigInt.new(number) * BigInt.new(n)) % BigInt.new(mod)).to_u64
      end
      count >>= 1
      n = ((BigInt.new(n) * BigInt.new(n)) % BigInt.new(mod)).to_u64
    end

    return number
  end

  def self.probably_prime(n : UInt64, k : Int32 = 100)
    if n < 6
      return [false, false, true, true, false, true][n]
    end

    if n % 2 == 0
      return false
    end

    s, d = 0, n - 1
    while d & 1 == 0
      s += 1
      d >>= 1
    end

    rnd = Random.new

    k.times do |i|
      a = rnd.rand(n - 4).to_u64 + 2
      x = pow(a, d, n)

      if x != 1 && x != n - 1
        (s - 1).times do |r|
          x = pow(x, 2_u64, n)

          if x == 1
            return false # composite for sure
          elsif x == n - 1
            a = 0 # so we know loop didn't continue to end
            break # could be strong liar, try another a
          end
        end

        if x != n - 1
          return false
        end
      end
    end
    return true
  end

  def self.probably_prime(n : Int32, k : Int32)
    probably_prime(n.to_u64, k)
  end
end

struct Number
  def prime?
    MillerRabin.probably_prime(to_u64)
  end
end
