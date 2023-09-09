require "./spec_helper"

include Raktor

private class Counter(T)
  include Sparse::IReport(T)

  getter count

  def initialize
    @count = 0
  end

  def reset
    @count = 0
  end

  def report(keys : Set(T))
    @count += keys.size
  end
end

describe Raktor::Sparse do
  describe "type" do
    it "should support type any" do
      q(%Q(any), Term::Str.new("hello world"), 0)
      q(%Q(any), Term::Num.new(123.4), 0)
      q(%Q(any), Term::Bool.new(true), 0)
      q(%Q(any), Term::Dict[], 0)
      q(%Q(any), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(any), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end

    it "should support type string" do
      q(%Q(string), Term::Str.new("hello world"), 0)
      q(%Q(string), Term::Num.new(123.4))
      q(%Q(string), Term::Bool.new(true))
      q(%Q(string), Term::Dict[])
      q(%Q(string), Term::Dict[Term::Num[1], Term::Num[2]])
      q(%Q(string), Term::Dict[a: Term::Num[1], b: Term::Num[2]])
    end

    it "should support type number" do
      q(%Q(number), Term::Str.new("hello world"))
      q(%Q(number), Term::Num.new(123.4), 0)
      q(%Q(number), Term::Bool.new(true))
      q(%Q(number), Term::Dict[])
      q(%Q(number), Term::Dict[Term::Num[1], Term::Num[2]])
      q(%Q(number), Term::Dict[a: Term::Num[1], b: Term::Num[2]])
      q(%Q(123_456), Term::Num.new(123_456), 0)
      q(%Q(123_456), Term::Num.new(100))
    end

    it "should support type bool" do
      q(%Q(bool), Term::Str.new("hello world"))
      q(%Q(bool), Term::Num.new(123.4))
      q(%Q(bool), Term::Bool.new(true), 0)
      q(%Q(bool), Term::Bool.new(false), 0)
      q(%Q(bool), Term::Dict[])
      q(%Q(bool), Term::Dict[Term::Num[1], Term::Num[2]])
      q(%Q(bool), Term::Dict[a: Term::Num[1], b: Term::Num[2]])
    end

    it "should support type dict" do
      q(%Q(dict), Term::Str.new("hello world"))
      q(%Q(dict), Term::Num.new(123.4))
      q(%Q(dict), Term::Bool.new(true))
      q(%Q(dict), Term::Bool.new(false))
      q(%Q(dict), Term::Dict[], 0)
      q(%Q(dict), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(dict), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end
  end

  describe "< <= isolated" do
    it "must match number" do
      q(%Q(< 100; <= 100), Term::Num.new(-100), 0, 1)
      q(%Q(< 100; <= 100), Term::Num.new(50), 0, 1)
      q(%Q(< 100; <= 100), Term::Num.new(100), 1)
      q(%Q(< 100; <= 100), Term::Num.new(150))
    end

    it "must not match other" do
      q(%Q(< 100; <= 100), Term::Str.new("hello world"))
      q(%Q(< 100; <= 100), Term::Bool.new(true))
      q(%Q(< 100; <= 100), Term::Dict[Term::Num.new(1), Term::Num.new(2), Term::Num.new(3)])
      q(%Q(< 100; <= 100), Term::Dict[a: Term::Num.new(1), b: Term::Num.new(2), c: Term::Num.new(3)])
    end

    it "must support combination with or" do
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Term::Num.new(-1000), 0, 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Term::Num.new(50), 0, 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Term::Num.new(100), 0, 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Term::Num.new(400), 0, 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Term::Num.new(500), 0, 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Term::Num.new(800), 0, 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Term::Num.new(1000), 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Term::Num.new(1500))
    end

    it "must support combination with and" do
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Term::Num.new(-1000), 0, 1)
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Term::Num.new(0), 0, 1)
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Term::Num.new(5), 0, 1)
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Term::Num.new(10), 1)
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Term::Num.new(40))
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Term::Num.new(50))
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Term::Num.new(1000))
    end

    it "must support merge" do
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Term::Num.new(-1000), 0, 1, 2, 3, 4, 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Term::Num.new(50), 0, 1, 2, 3, 4, 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Term::Num.new(100), 1, 2, 3, 4, 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Term::Num.new(400), 1, 2, 4, 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Term::Num.new(500), 2, 4, 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Term::Num.new(800), 2, 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Term::Num.new(1000), 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Term::Num.new(1500))
    end

    it "must support alt" do
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Term::Num.new(-1000), 0, 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Term::Num.new(50), 0, 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Term::Num.new(100), 0, 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Term::Num.new(400), 0, 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Term::Num.new(500), 0, 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Term::Num.new(800), 0, 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Term::Num.new(1000), 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Term::Num.new(1500))
    end

    it "must support alt merge" do
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Term::Num.new(-1000), 0, 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Term::Num.new(50), 0, 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Term::Num.new(100), 0, 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Term::Num.new(400), 0, 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Term::Num.new(500), 0, 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Term::Num.new(800), 0, 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Term::Num.new(1000), 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Term::Num.new(1500), 1, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Term::Num.new(2000), 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Term::Num.new(2500))
    end
  end

  describe "> >= isolated" do
    it "must match number" do
      q(%Q(> 100; >= 100), Term::Num.new(-100))
      q(%Q(> 100; >= 100), Term::Num.new(50))
      q(%Q(> 100; >= 100), Term::Num.new(100), 1)
      q(%Q(> 100; >= 100), Term::Num.new(150), 0, 1)
    end

    it "must not match other" do
      q(%Q(> 100; >= 100), Term::Str.new("hello world"))
      q(%Q(> 100; >= 100), Term::Bool.new(true))
      q(%Q(> 100; >= 100), Term::Dict[Term::Num.new(1), Term::Num.new(2), Term::Num.new(3)])
      q(%Q(> 100; >= 100), Term::Dict[a: Term::Num.new(1), b: Term::Num.new(2), c: Term::Num.new(3)])
    end

    it "must support combination with or" do
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Term::Num.new(-1000))
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Term::Num.new(50))
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Term::Num.new(100), 1)
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Term::Num.new(400), 0, 1)
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Term::Num.new(500), 0, 1)
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Term::Num.new(800), 0, 1)
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Term::Num.new(1000), 0, 1)
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Term::Num.new(1500), 0, 1)
    end

    it "must support combination with and" do
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Term::Num.new(-1000))
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Term::Num.new(0))
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Term::Num.new(5))
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Term::Num.new(10))
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Term::Num.new(40))
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Term::Num.new(50))
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Term::Num.new(100), 1)
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Term::Num.new(101), 0, 1)
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Term::Num.new(300), 0, 1)
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Term::Num.new(1000), 0, 1)
    end

    it "must support merge" do
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Term::Num.new(-1000))
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Term::Num.new(50))
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Term::Num.new(100), 3)
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Term::Num.new(400), 0, 3)
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Term::Num.new(500), 0, 3, 4)
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Term::Num.new(800), 0, 1, 3, 4)
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Term::Num.new(1000), 0, 1, 3, 4, 5)
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Term::Num.new(1500), 0, 1, 2, 3, 4, 5)
    end

    it "must support alt" do
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Term::Num.new(-1000))
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Term::Num.new(50))
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Term::Num.new(100), 1)
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Term::Num.new(400), 0, 1)
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Term::Num.new(500), 0, 1)
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Term::Num.new(800), 0, 1)
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Term::Num.new(1000), 0, 1)
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Term::Num.new(1500), 0, 1)
    end

    it "must support alt merge" do
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Term::Num.new(-1000))
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Term::Num.new(50))
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Term::Num.new(100), 2)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Term::Num.new(400), 0, 1, 2, 3)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Term::Num.new(500), 0, 1, 2, 3)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Term::Num.new(800), 0, 1, 2, 3)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Term::Num.new(1000), 0, 1, 2, 3)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Term::Num.new(1500), 0, 1, 2, 3)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Term::Num.new(2000), 0, 1, 2, 3)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Term::Num.new(2500), 0, 1, 2, 3)
    end
  end

  describe "/? isolated" do
    it "must match number" do
      q(%Q(/? 10), Term::Num.new(0), 0)
      q(%Q(/? 10), Term::Num.new(100), 0)
      q(%Q(/? 10), Term::Num.new(120), 0)
      q(%Q(/? 10), Term::Num.new(125))
      q(%Q(/? 10), Term::Num.new(127))
      q(%Q(/? 10), Term::Num.new(126))
      q(%Q(/? 10), Term::Num.new(-100), 0)
      q(%Q(/? 10), Term::Num.new(-15))
      q(%Q(/? 10), Term::Num.new(-13))
      q(%Q(/? 10), Term::Num.new(-1))
    end

    it "must not match any number if arg is 0" do
      q(%Q(/? 0), Term::Num.new(0))
      q(%Q(/? 0), Term::Num.new(123))
      q(%Q(/? 0), Term::Num.new(-100))
    end

    it "must not match other" do
      q(%Q(/? 10), Term::Str.new("hello world"))
      q(%Q(/? 10), Term::Bool.new(true))
      q(%Q(/? 10), Term::Dict[Term::Num.new(1), Term::Num.new(2), Term::Num.new(3)])
      q(%Q(/? 10), Term::Dict[a: Term::Num.new(1), b: Term::Num.new(2), c: Term::Num.new(3)])
    end

    it "must support combination with or" do
      q(%Q(/? 5 or /? 15), Term::Num.new(0), 0)
      q(%Q(/? 5 or /? 15), Term::Num.new(100), 0)
      q(%Q(/? 5 or /? 15), Term::Num.new(15), 0)
      q(%Q(/? 5 or /? 15), Term::Num.new(30), 0)
      q(%Q(/? 5 or /? 15), Term::Num.new(45), 0)
      q(%Q(/? 5 or /? 15), Term::Num.new(120), 0)
      q(%Q(/? 5 or /? 15), Term::Num.new(125), 0)
      q(%Q(/? 5 or /? 15), Term::Num.new(127))
      q(%Q(/? 5 or /? 15), Term::Num.new(126))
      q(%Q(/? 5 or /? 15), Term::Num.new(-100), 0)
      q(%Q(/? 5 or /? 15), Term::Num.new(-125), 0)
      q(%Q(/? 5 or /? 15), Term::Num.new(-15), 0)
      q(%Q(/? 5 or /? 15), Term::Num.new(-13))
      q(%Q(/? 5 or /? 15), Term::Num.new(-1))
    end

    it "must support combination with and" do
      q(%Q(/? 5 /? 15), Term::Num.new(0), 0)
      q(%Q(/? 5 /? 15), Term::Num.new(100))
      q(%Q(/? 5 /? 15), Term::Num.new(15), 0)
      q(%Q(/? 5 /? 15), Term::Num.new(30), 0)
      q(%Q(/? 5 /? 15), Term::Num.new(45), 0)
      q(%Q(/? 5 /? 15), Term::Num.new(120), 0)
      q(%Q(/? 5 /? 15), Term::Num.new(125))
      q(%Q(/? 5 /? 15), Term::Num.new(127))
      q(%Q(/? 5 /? 15), Term::Num.new(126))
      q(%Q(/? 5 /? 15), Term::Num.new(-100))
      q(%Q(/? 5 /? 15), Term::Num.new(-125))
      q(%Q(/? 5 /? 15), Term::Num.new(-15), 0)
      q(%Q(/? 5 /? 15), Term::Num.new(-13))
      q(%Q(/? 5 /? 15), Term::Num.new(-1))
    end

    it "must support alt" do
      q(%Q(/? 5 | 15), Term::Num.new(0), 0)
      q(%Q(/? 5 | 15), Term::Num.new(100), 0)
      q(%Q(/? 5 | 15), Term::Num.new(15), 0)
      q(%Q(/? 5 | 15), Term::Num.new(30), 0)
      q(%Q(/? 5 | 15), Term::Num.new(45), 0)
      q(%Q(/? 5 | 15), Term::Num.new(120), 0)
      q(%Q(/? 5 | 15), Term::Num.new(125), 0)
      q(%Q(/? 5 | 15), Term::Num.new(127))
      q(%Q(/? 5 | 15), Term::Num.new(126))
      q(%Q(/? 5 | 15), Term::Num.new(-100), 0)
      q(%Q(/? 5 | 15), Term::Num.new(-125), 0)
      q(%Q(/? 5 | 15), Term::Num.new(-15), 0)
      q(%Q(/? 5 | 15), Term::Num.new(-13))
      q(%Q(/? 5 | 15), Term::Num.new(-1))
    end

    it "must support merge" do
      q(%Q(/? 5; /? 15), Term::Num.new(0), 0, 1)
      q(%Q(/? 5; /? 15), Term::Num.new(100), 0)
      q(%Q(/? 5; /? 15), Term::Num.new(15), 0, 1)
      q(%Q(/? 5; /? 15), Term::Num.new(30), 0, 1)
      q(%Q(/? 5; /? 15), Term::Num.new(45), 0, 1)
      q(%Q(/? 5; /? 15), Term::Num.new(120), 0, 1)
      q(%Q(/? 5; /? 15), Term::Num.new(125), 0)
      q(%Q(/? 5; /? 15), Term::Num.new(127))
      q(%Q(/? 5; /? 15), Term::Num.new(126))
      q(%Q(/? 5; /? 15), Term::Num.new(-100), 0)
      q(%Q(/? 5; /? 15), Term::Num.new(-125), 0)
      q(%Q(/? 5; /? 15), Term::Num.new(-15), 0, 1)
      q(%Q(/? 5; /? 15), Term::Num.new(-13))
      q(%Q(/? 5; /? 15), Term::Num.new(-1))
    end

    it "must support alt merge" do
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(-100), 0, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(0), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(3), 1, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(5), 0, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(7))
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(8), 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(15), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(30), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(40), 0, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(45), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(44.5))
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(48), 1, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Term::Num.new(135), 0, 1, 2, 3)
    end

    it "must support and merge" do
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Term::Num.new(-100), 0)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Term::Num.new(0), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Term::Num.new(3), 1)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Term::Num.new(5), 0)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Term::Num.new(7))
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Term::Num.new(15), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Term::Num.new(30), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Term::Num.new(40), 0)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Term::Num.new(45), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Term::Num.new(48), 1)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Term::Num.new(135), 0, 1, 2, 3)
    end

    it "must support or merge" do
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Term::Num.new(-100), 0, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Term::Num.new(0), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Term::Num.new(3), 1, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Term::Num.new(5), 0, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Term::Num.new(7))
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Term::Num.new(8), 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Term::Num.new(15), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Term::Num.new(30), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Term::Num.new(40), 0, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Term::Num.new(45), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Term::Num.new(48), 1, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Term::Num.new(135), 0, 1, 2, 3)
    end
  end

  describe "..=Y X..= X..=Y ..<Y X..< X..<Y ..< ..= isolated" do
    it "must support beginless inclusive, exclusve" do
      q(%Q(..=100), Term::Num.new(-1000.456), 0)
      q(%Q(..=100), Term::Num.new(30), 0)
      q(%Q(..=100), Term::Num.new(100), 0)
      q(%Q(..=100), Term::Num.new(150))

      q(%Q(..<100), Term::Num.new(-1000.456), 0)
      q(%Q(..<100), Term::Num.new(30), 0)
      q(%Q(..<100), Term::Num.new(100))
      q(%Q(..<100), Term::Num.new(150))
    end

    it "must support endless inclusive, exclusive" do
      q(%Q(100..=), Term::Num.new(-1000.456))
      q(%Q(100..=), Term::Num.new(100), 0)
      q(%Q(100..=), Term::Num.new(150), 0)
      q(%Q(100..=), Term::Num.new(1000), 0)

      q(%Q(100..<), Term::Num.new(-1000.456))
      q(%Q(100..<), Term::Num.new(100), 0)
      q(%Q(100..<), Term::Num.new(150), 0)
      q(%Q(100..<), Term::Num.new(1000), 0)
    end

    it "must support inclusive" do
      q(%Q(0..=100), Term::Num.new(-1000.456))
      q(%Q(0..=100), Term::Num.new(0), 0)
      q(%Q(0..=100), Term::Num.new(80), 0)
      q(%Q(0..=100), Term::Num.new(100), 0)
      q(%Q(0..=100), Term::Num.new(1000))
    end

    it "must support exclusive" do
      q(%Q(0..<100), Term::Num.new(-1000.456))
      q(%Q(0..<100), Term::Num.new(0), 0)
      q(%Q(0..<100), Term::Num.new(80), 0)
      q(%Q(0..<100), Term::Num.new(100))
      q(%Q(0..<100), Term::Num.new(1000))
    end

    it "must support combination with and" do
      q(%Q(0..=100 50..=80), Term::Num.new(-1000.456))
      q(%Q(0..=100 50..=80), Term::Num.new(0))
      q(%Q(0..=100 50..=80), Term::Num.new(30))
      q(%Q(0..=100 50..=80), Term::Num.new(50), 0)
      q(%Q(0..=100 50..=80), Term::Num.new(70), 0)
      q(%Q(0..=100 50..=80), Term::Num.new(80), 0)
      q(%Q(0..=100 50..=80), Term::Num.new(90))
      q(%Q(0..=100 50..=80), Term::Num.new(100))
      q(%Q(0..=100 50..=80), Term::Num.new(150))

      q(%Q(0..<100 50..<80), Term::Num.new(-1000.456))
      q(%Q(0..<100 50..<80), Term::Num.new(0))
      q(%Q(0..<100 50..<80), Term::Num.new(30))
      q(%Q(0..<100 50..<80), Term::Num.new(50), 0)
      q(%Q(0..<100 50..<80), Term::Num.new(70), 0)
      q(%Q(0..<100 50..<80), Term::Num.new(80))
      q(%Q(0..<100 50..<80), Term::Num.new(90))
      q(%Q(0..<100 50..<80), Term::Num.new(100))
      q(%Q(0..<100 50..<80), Term::Num.new(150))
    end

    it "must support combination with or" do
      q(%Q(0..=100 or 50..=80), Term::Num.new(-1000.456))
      q(%Q(0..=100 or 50..=80), Term::Num.new(0), 0)
      q(%Q(0..=100 or 50..=80), Term::Num.new(30), 0)
      q(%Q(0..=100 or 50..=80), Term::Num.new(50), 0)
      q(%Q(0..=100 or 50..=80), Term::Num.new(70), 0)
      q(%Q(0..=100 or 50..=80), Term::Num.new(80), 0)
      q(%Q(0..=100 or 50..=80), Term::Num.new(90), 0)
      q(%Q(0..=100 or 50..=80), Term::Num.new(100), 0)
      q(%Q(0..=100 or 50..=80), Term::Num.new(150))

      q(%Q(0..<100 or 50..<80), Term::Num.new(-1000.456))
      q(%Q(0..<100 or 50..<80), Term::Num.new(0), 0)
      q(%Q(0..<100 or 50..<80), Term::Num.new(30), 0)
      q(%Q(0..<100 or 50..<80), Term::Num.new(50), 0)
      q(%Q(0..<100 or 50..<80), Term::Num.new(70), 0)
      q(%Q(0..<100 or 50..<80), Term::Num.new(80), 0)
      q(%Q(0..<100 or 50..<80), Term::Num.new(90), 0)
      q(%Q(0..<100 or 50..<80), Term::Num.new(100))
      q(%Q(0..<100 or 50..<80), Term::Num.new(150))
    end

    it "must support merge" do
      q(%Q(0..=100; 50..=80), Term::Num.new(-1000.456))
      q(%Q(0..=100; 50..=80), Term::Num.new(0), 0)
      q(%Q(0..=100; 50..=80), Term::Num.new(30), 0)
      q(%Q(0..=100; 50..=80), Term::Num.new(50), 0, 1)
      q(%Q(0..=100; 50..=80), Term::Num.new(70), 0, 1)
      q(%Q(0..=100; 50..=80), Term::Num.new(80), 0, 1)
      q(%Q(0..=100; 50..<80), Term::Num.new(80), 0)
      q(%Q(0..=100; 50..=80), Term::Num.new(90), 0)
      q(%Q(0..=100; 50..=80), Term::Num.new(100), 0)
      q(%Q(0..<100; 50..=80), Term::Num.new(100))
      q(%Q(0..=100; 50..=80), Term::Num.new(150))
    end

    it "must combine with type well" do
      q(%Q(0..=100 number), Term::Num.new(-1000.456))
      q(%Q(0..=100 number), Term::Num.new(0), 0)
      q(%Q(0..=100 number), Term::Num.new(30), 0)
      q(%Q(0..=100 number), Term::Num.new(100), 0)
      q(%Q(0..<100 number), Term::Num.new(100))
      q(%Q(0..=100 number), Term::Num.new(150))

      q(%Q(0..=100 or number), Term::Num.new(-1000.456), 0)
      q(%Q(0..=100 or number), Term::Num.new(0), 0)
      q(%Q(0..=100 or number), Term::Num.new(30), 0)
      q(%Q(0..=100 or number), Term::Num.new(100), 0)
      q(%Q(0..<100 or number), Term::Num.new(100), 0)
      q(%Q(0..=100 or number), Term::Num.new(150), 0)

      q(%Q(number; 0..=100), Term::Num.new(-1000.456), 0)
      q(%Q(number; 0..=100), Term::Num.new(0), 0, 1)
      q(%Q(number; 0..=100), Term::Num.new(30), 0, 1)
      q(%Q(number; 0..=100), Term::Num.new(100), 0, 1)
      q(%Q(number; 0..<100), Term::Num.new(100), 0)
      q(%Q(number; 0..=100), Term::Num.new(150), 0)
    end

    it "must combine with exact well" do
      q(%Q(123 or -100 or 0..=100), Term::Num.new(-1000.456))
      q(%Q(123 or -100 or 0..=100), Term::Num.new(-100), 0)
      q(%Q(123 or -100 or 0..=100), Term::Num.new(-50))
      q(%Q(123 or -100 or 0..=100), Term::Num.new(0), 0)
      q(%Q(123 or -100 or 0..=100), Term::Num.new(50), 0)
      q(%Q(123 or -100 or 0..=100), Term::Num.new(100), 0)
      q(%Q(123 or -100 or 0..<100), Term::Num.new(100))
      q(%Q(123 or -100 or 0..=100), Term::Num.new(105))
      q(%Q(123 or -100 or 0..=100), Term::Num.new(123), 0)
      q(%Q(123 or -100 or 0..=100), Term::Num.new(155))

      q(%Q(123; -100; 50; 0..=100), Term::Num.new(-1000.456))
      q(%Q(123; -100; 50; 0..=100), Term::Num.new(-100), 1)
      q(%Q(123; -100; 50; 0..=100), Term::Num.new(-50))
      q(%Q(123; -100; 50; 0..=100), Term::Num.new(0), 3)
      q(%Q(123; -100; 50; 0..=100), Term::Num.new(50), 2, 3)
      q(%Q(123; -100; 50; 0..=100), Term::Num.new(100), 3)
      q(%Q(123; -100; 50; 0..<100), Term::Num.new(100))
      q(%Q(123; -100; 50; 0..=100), Term::Num.new(105))
      q(%Q(123; -100; 50; 0..=100), Term::Num.new(123), 0)
      q(%Q(123; -100; 50; 0..=100), Term::Num.new(155))
    end
  end

  describe "list dict" do
    it "must match exact" do
      q(%Q([1, 2, 3]), Term::Dict[Term::Num.new(1), Term::Num.new(2), Term::Num.new(3)], 0)
      q(%Q([1, 2, 3]), Term::Dict[Term::Num.new(100), Term::Num.new(2), Term::Num.new(3)])
      q(%Q([1, 2, 3]), Term::Dict[Term::Num.new(1), Term::Num.new(200), Term::Num.new(3)])
      q(%Q([1, 2, 3]), Term::Dict[Term::Num.new(1), Term::Num.new(2), Term::Num.new(300)])
      q(%Q([1, 2, 3]), Term::Dict[Term::Num.new(1), Term::Num.new(2)])
      q(%Q([1, 2, 3]), Term::Dict[Term::Num.new(1)])
      q(%Q([1, 2, 3]), Term::Dict[Term::Num.new(2)])
      q(%Q([1, 2, 3]), Term::Dict[Term::Num.new(3)])
      q(%Q([1, 2, 3]), Term::Dict[Term::Num.new(123)])
      q(%Q([1, 2, 3]), Term::Dict[])
    end

    it "must match if more than specified" do
      q(%Q([1, 2, 3]), Term::Dict[Term::Num.new(1), Term::Num.new(2), Term::Num.new(3), Term::Num.new(4)], 0)
      q(%Q([1, 2, 3]), Term::Dict[Term::Num.new(1), Term::Num.new(2), Term::Num.new(3), Term::Str.new("foobar")], 0)
      # ...
    end

    it "must work with conditions and nesting" do
      q1 = %Q([string, /? 100 > 100 not(200), [number, number]])
      q(q1, Term::Num.new(300))
      q(q1, Term::Dict[])
      q(q1, Term::Dict[Term::Str.new("hello")])
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(300)])
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(300), Term::Dict[]])
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(300), Term::Dict[Term::Num.new(123)]])
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(300), Term::Dict[Term::Num.new(123), Term::Num.new(456)]], 0)
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(10), Term::Dict[Term::Num.new(123), Term::Num.new(456)]])
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(64), Term::Dict[Term::Num.new(123), Term::Num.new(456)]])
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(100), Term::Dict[Term::Num.new(123), Term::Num.new(456)]])
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(1234), Term::Dict[Term::Num.new(123), Term::Num.new(456)]])
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(200), Term::Dict[Term::Num.new(123), Term::Num.new(456)]])
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(300), Term::Dict[Term::Num.new(123), Term::Num.new(456)]], 0)
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(400), Term::Dict[Term::Num.new(123), Term::Num.new(456)]], 0)
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(1000), Term::Dict[Term::Num.new(123), Term::Num.new(456)]], 0)
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(300), Term::Dict[Term::Num.new(123), Term::Str.new("hello")]])
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(300), Term::Dict[Term::Str.new("hello"), Term::Num.new(123)]])
      q(q1, Term::Dict[Term::Num.new(123), Term::Num.new(300), Term::Dict[Term::Num.new(123), Term::Num.new(456)]])
    end

    it "must combine and merge well" do
      q1 = %Q([number, number] [100, 200])
      q(q1, Term::Num.new(100))
      q(q1, Term::Num.new(200))
      q(q1, Term::Dict[])
      q(q1, Term::Dict[Term::Str.new("hello"), Term::Num.new(456)])
      q(q1, Term::Dict[Term::Num.new(123), Term::Num.new(456)])
      q(q1, Term::Dict[Term::Num.new(100), Term::Num.new(456)])
      q(q1, Term::Dict[Term::Num.new(100), Term::Str.new("world")])
      q(q1, Term::Dict[Term::Num.new(123), Term::Num.new(200)])
      q(q1, Term::Dict[Term::Num.new(100), Term::Num.new(200)], 0)
      q(q1, Term::Dict[Term::Num.new(100), Term::Num.new(200), Term::Str.new("hello world")], 0)

      q2 = %Q([]; []; [] or [100]; [1, 2, 3]; [number, number, number]; [number or string, number, number]; dict; [string])
      q(q2, Term::Num.new(100))
      q(q2, Term::Dict[], 0, 1, 2, 6)
      q(q2, Term::Dict[Term::Str.new("hello")], 0, 1, 2, 6, 7)
      q(q2, Term::Dict[Term::Num.new(100)], 0, 1, 2, 6)
      q(q2, Term::Dict[Term::Num.new(1), Term::Num.new(2), Term::Num.new(3)], 0, 1, 2, 3, 4, 5, 6)
      q(q2, Term::Dict[Term::Num.new(1), Term::Num.new(100), Term::Num.new(3)], 0, 1, 2, 4, 5, 6)
      q(q2, Term::Dict[Term::Str.new("hello"), Term::Num.new(2), Term::Num.new(3)], 0, 1, 2, 5, 6, 7)

      q3 = %Q([/? 100 > 100 not(200)] or number; [/? 200 > 300 not(300)] or string or 456)
      q(q3, Term::Num.new(123), 0)
      q(q3, Term::Str.new("hello"), 1)
      q(q3, Term::Num.new(456), 0, 1)
      q(q3, Term::Dict[])
      q(q3, Term::Dict[Term::Num.new(0)])
      q(q3, Term::Dict[Term::Num.new(123)])
      q(q3, Term::Dict[Term::Num.new(100)])
      q(q3, Term::Dict[Term::Num.new(200)])
      q(q3, Term::Dict[Term::Num.new(300)], 0)
      q(q3, Term::Dict[Term::Num.new(400)], 0, 1)
      q(q3, Term::Dict[Term::Num.new(500)], 0)
      q(q3, Term::Dict[Term::Num.new(600)], 0, 1)
      q(q3, Term::Dict[Term::Num.new(-500)])
      q(q3, Term::Dict[Term::Num.new(-600)])
    end
  end

  describe "dict" do
    it "must access 01 with overlaps" do
      q1 = %Q({ name: "John Doe", age /? 100 }; { name: "Jane Doe", age 0..=100 /? 5, foo: string}; { foo: string, bar: number }; { bar: string })

      q(q1, Term::Dict[name: Term::Str.new("John Doe")])
      q(q1, Term::Dict[name: Term::Str.new("John Doe"), foo: Term::Str.new("hello world")])
      q(q1, Term::Dict[name: Term::Str.new("John Doe"), foo: Term::Str.new("hello world"), bar: Term::Num.new(123)], 2)
      q(q1, Term::Dict[name: Term::Str.new("John Doe"), foo: Term::Str.new("hello world"), bar: Term::Str.new("hello bar")], 3)
      q(q1, Term::Dict[
        name: Term::Str.new("John Doe"),
        age: Term::Num.new(24),
        foo: Term::Str.new("hello world"),
        bar: Term::Str.new("hello bar"),
      ], 3)
      q(q1, Term::Dict[
        name: Term::Str.new("John Doe"),
        age: Term::Num.new(24),
        foo: Term::Str.new("hello world"),
        bar: Term::Num.new(123),
      ], 2)
      q(q1, Term::Dict[
        name: Term::Str.new("John Doe"),
        age: Term::Num.new(200),
        foo: Term::Str.new("hello world"),
        bar: Term::Str.new("hello bar"),
      ], 0, 3)
      q(q1, Term::Dict[
        name: Term::Str.new("John Doe"),
        age: Term::Num.new(200),
        foo: Term::Str.new("hello world"),
        bar: Term::Num.new(123),
      ], 0, 2)
      q(q1, Term::Dict[
        name: Term::Str.new("Jane Doe"),
        age: Term::Num.new(-100),
      ])
      q(q1, Term::Dict[
        name: Term::Str.new("Jane Doe"),
        age: Term::Num.new(200),
      ])
      q(q1, Term::Dict[
        name: Term::Str.new("Jane Doe"),
        age: Term::Num.new(53),
      ])
      q(q1, Term::Dict[
        name: Term::Str.new("Jane Doe"),
        age: Term::Num.new(50),
      ])
      q(q1, Term::Dict[
        name: Term::Str.new("Jane Doe"),
        age: Term::Num.new(50),
        foo: Term::Num.new(50),
      ])
      q(q1, Term::Dict[
        name: Term::Str.new("Jane Doe"),
        age: Term::Num.new(50),
        foo: Term::Str.new("hello world"),
      ], 1)
      q(q1, Term::Dict[
        name: Term::Str.new("Jane Doe"),
        age: Term::Num.new(53),
        foo: Term::Str.new("hello world"),
      ])
      q(q1, Term::Dict[
        name: Term::Str.new("Jane Doe"),
        age: Term::Num.new(0),
        foo: Term::Str.new("hello world"),
      ], 1)
      q(q1, Term::Dict[
        name: Term::Str.new("Jane Doe"),
        age: Term::Num.new(100),
        foo: Term::Str.new("hello world"),
      ], 1)
      q(q1, Term::Dict[
        name: Term::Str.new("Jane Doe"),
        age: Term::Num.new(100),
        foo: Term::Str.new("hello world"),
        bar: Term::Num.new(123),
      ], 1, 2)
      q(q1, Term::Dict[
        name: Term::Str.new("Jane Doe"),
        age: Term::Num.new(100),
        foo: Term::Str.new("hello world"),
        bar: Term::Str.new("bye world"),
      ], 1, 3)
      q(q1, Term::Dict[
        name: Term::Str.new("John Doe"),
        age: Term::Num.new(100),
        foo: Term::Str.new("hello world"),
        bar: Term::Str.new("bye world"),
      ], 0, 3)
    end

    it "must access 2" do
      q1 = %Q({ name: "John Doe", age /? 100 }; { name: "Jane Doe", age 0..=100 /? 5, foo: string}; { foo: string, bar: number }; { bar: string })

      q(q1, Term::Dict[foo: Term::Str.new("hello world"), bar: Term::Num.new(123)], 2)
      q(q1, Term::Dict[foo: Term::Str.new("hello world")])
    end

    it "must access 3" do
      q1 = %Q({ name: "John Doe", age /? 100 }; { name: "Jane Doe", age 0..=100 /? 5, foo: string}; { foo: string, bar: number }; { bar: string })

      q(q1, Term::Dict[bar: Term::Str.new("fooze")], 3)
      q(q1, Term::Dict[foo: Term::Str.new("hello world"), bar: Term::Str.new("foobrazaur")], 3)
      q(q1, Term::Dict[bar: Term::Num.new(123)])
    end
  end

  describe "basic not(...)" do
    it "must work for basic exacts" do
      q(%Q(not(123)), Term::Num.new(100), 0)
      q(%Q(not(123)), Term::Str.new("hello world"), 0)
      q(%Q(not(123)), Term::Num.new(123))
      q(%Q(not(123)), Term::Num.new(123.456), 0)
      q(%Q(not(123)), Term::Num.new(-123), 0)

      q(%Q(not("hello world")), Term::Str.new("foobar"), 0)
      q(%Q(not("hello world")), Term::Num.new(123), 0)
      q(%Q(not("hello world")), Term::Str.new("hello world"))
      q(%Q(not("hello world")), Term::Str.new("hello worldo"), 0)

      q(%Q(not(true)), Term::Bool.new(false), 0)
      q(%Q(not(true)), Term::Bool.new(true))
      q(%Q(not(true)), Term::Str.new(""), 0)
      q(%Q(not(true)), Term::Num.new(0), 0)

      q(%Q(not(false)), Term::Bool.new(false))
      q(%Q(not(false)), Term::Bool.new(true), 0)
      q(%Q(not(false)), Term::Str.new(""), 0)
      q(%Q(not(false)), Term::Num.new(0), 0)
    end

    it "must allow to negate type any" do
      q(%Q(not(any)), Term::Str.new("hello world"))
      q(%Q(not(any)), Term::Num.new(123.4))
      q(%Q(not(any)), Term::Bool.new(true))
      q(%Q(not(any)), Term::Dict[])
      q(%Q(not(any)), Term::Dict[Term::Num[1], Term::Num[2]])
      q(%Q(not(any)), Term::Dict[a: Term::Num[1], b: Term::Num[2]])
    end

    it "must allow to negate type string" do
      q(%Q(not(string)), Term::Str.new("hello world"))
      q(%Q(not(string)), Term::Num.new(123.4), 0)
      q(%Q(not(string)), Term::Bool.new(true), 0)
      q(%Q(not(string)), Term::Dict[], 0)
      q(%Q(not(string)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(string)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end

    it "must allow to negate type number" do
      q(%Q(not(number)), Term::Str.new("hello world"), 0)
      q(%Q(not(number)), Term::Num.new(123.4))
      q(%Q(not(number)), Term::Bool.new(true), 0)
      q(%Q(not(number)), Term::Dict[], 0)
      q(%Q(not(number)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(number)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end

    it "must allow to negate type bool" do
      q(%Q(not(bool)), Term::Str.new("hello world"), 0)
      q(%Q(not(bool)), Term::Num.new(123.4), 0)
      q(%Q(not(bool)), Term::Bool.new(true))
      q(%Q(not(bool)), Term::Dict[], 0)
      q(%Q(not(bool)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(bool)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end

    it "must allow to negate type dict" do
      q(%Q(not(dict)), Term::Str.new("hello world"), 0)
      q(%Q(not(dict)), Term::Num.new(123.4), 0)
      q(%Q(not(dict)), Term::Bool.new(true), 0)
      q(%Q(not(dict)), Term::Dict[])
      q(%Q(not(dict)), Term::Dict[Term::Num[1], Term::Num[2]])
      q(%Q(not(dict)), Term::Dict[a: Term::Num[1], b: Term::Num[2]])
    end

    it "must handle nesting well" do
      q(%Q(not(not(123))), Term::Num.new(100))
      q(%Q(not(not(123))), Term::Str.new("hello world"))
      q(%Q(not(not(123))), Term::Num.new(123), 0)
      q(%Q(not(not(123))), Term::Num.new(123.456))
      q(%Q(not(not(123))), Term::Num.new(-123))

      q(%Q(not(not("hello world"))), Term::Str.new("foobar"))
      q(%Q(not(not("hello world"))), Term::Num.new(123))
      q(%Q(not(not("hello world"))), Term::Str.new("hello world"), 0)
      q(%Q(not(not("hello world"))), Term::Str.new("hello worldo"))

      q(%Q(not(not(true))), Term::Bool.new(false))
      q(%Q(not(not(true))), Term::Bool.new(true), 0)
      q(%Q(not(not(true))), Term::Str.new(""))
      q(%Q(not(not(true))), Term::Num.new(0))

      q(%Q(not(not(false))), Term::Bool.new(false), 0)
      q(%Q(not(not(false))), Term::Bool.new(true))
      q(%Q(not(not(false))), Term::Str.new(""))
      q(%Q(not(not(false))), Term::Num.new(0))

      q(%Q(not(not(not(123)))), Term::Num.new(100), 0)
      q(%Q(not(not(not(123)))), Term::Str.new("hello world"), 0)
      q(%Q(not(not(not(123)))), Term::Num.new(123))
      q(%Q(not(not(not(123)))), Term::Num.new(123.456), 0)
      q(%Q(not(not(not(123)))), Term::Num.new(-123), 0)

      q(%Q(not(not(not("hello world")))), Term::Str.new("foobar"), 0)
      q(%Q(not(not(not("hello world")))), Term::Num.new(123), 0)
      q(%Q(not(not(not("hello world")))), Term::Str.new("hello world"))
      q(%Q(not(not(not("hello world")))), Term::Str.new("hello worldo"), 0)

      q(%Q(not(not(not(true)))), Term::Bool.new(false), 0)
      q(%Q(not(not(not(true)))), Term::Bool.new(true))
      q(%Q(not(not(not(true)))), Term::Str.new(""), 0)
      q(%Q(not(not(not(true)))), Term::Num.new(0), 0)

      q(%Q(not(not(not(false)))), Term::Bool.new(false))
      q(%Q(not(not(not(false)))), Term::Bool.new(true), 0)
      q(%Q(not(not(not(false)))), Term::Str.new(""), 0)
      q(%Q(not(not(not(false)))), Term::Num.new(0), 0)
    end

    it "must support exact dict" do
      q1 = %Q(not({ name string, age /? 2 }))
      q(q1, Term::Num.new(123), 0)
      q(q1, Term::Bool.new(true), 0)
      q(q1, Term::Str.new("hello"), 0)
      q(q1, Term::Dict[], 0)
      q(q1, Term::Dict[name: Term::Str.new("John Doe")], 0)
      q(q1, Term::Dict[name: Term::Str.new("John Doe"), age: Term::Num.new(123)], 0)
      q(q1, Term::Dict[name: Term::Str.new("John Doe"), age: Term::Num.new(124)])
      q(q1, Term::Dict[name: Term::Str.new("John Doe"), age: Term::Num.new(124), foo: Term::Str.new("bar")])
      q(q1, Term::Dict[name: Term::Num.new(123), age: Term::Num.new(124), foo: Term::Str.new("bar")], 0)
      q(q1, Term::Dict[name: Term::Str.new("John Doe"), age: Term::Num.new(124.5), foo: Term::Str.new("bar")], 0)
    end
  end

  describe "not(< > <= >= /? ..= ..< ...) given a number" do
    it "must support not(< <number>)" do
      q(%Q(not(< 100)), Term::Num.new(-123))
      q(%Q(not(< 100)), Term::Num.new(100), 0)
      q(%Q(not(< 100)), Term::Num.new(123), 0)
    end

    it "must support not(> <number>)" do
      q(%Q(not(> 100)), Term::Num.new(-123), 0)
      q(%Q(not(> 100)), Term::Num.new(100), 0)
      q(%Q(not(> 100)), Term::Num.new(123))
    end

    it "must support not(<= <number>)" do
      q(%Q(not(<= 100)), Term::Num.new(-123))
      q(%Q(not(<= 100)), Term::Num.new(100))
      q(%Q(not(<= 100)), Term::Num.new(123), 0)
    end

    it "must support not(>= <number>)" do
      q(%Q(not(>= 100)), Term::Num.new(-123), 0)
      q(%Q(not(>= 100)), Term::Num.new(100))
      q(%Q(not(>= 100)), Term::Num.new(123))
    end

    it "must support not(/? <number>)" do
      q(%Q(not(/? 10)), Term::Num.new(-123), 0)
      q(%Q(not(/? 10)), Term::Num.new(-100))
      q(%Q(not(/? 10)), Term::Num.new(-15), 0)
      q(%Q(not(/? 10)), Term::Num.new(0))
      q(%Q(not(/? 10)), Term::Num.new(10))
      q(%Q(not(/? 10)), Term::Num.new(13), 0)
      q(%Q(not(/? 10)), Term::Num.new(15), 0)
      q(%Q(not(/? 10)), Term::Num.new(100))
    end

    it "must support not(..=<number>) and not(..<<number>)" do
      q(%Q(not(..=100)), Term::Num.new(-1000.456))
      q(%Q(not(..=100)), Term::Num.new(30))
      q(%Q(not(..=100)), Term::Num.new(100))
      q(%Q(not(..=100)), Term::Num.new(150), 0)

      q(%Q(not(..<100)), Term::Num.new(-1000.456))
      q(%Q(not(..<100)), Term::Num.new(30))
      q(%Q(not(..<100)), Term::Num.new(100), 0)
      q(%Q(not(..<100)), Term::Num.new(150), 0)
    end

    it "must support not(<number>..=) and not(<number>..<)" do
      q(%Q(not(100..=)), Term::Num.new(-1000.456), 0)
      q(%Q(not(100..=)), Term::Num.new(100))
      q(%Q(not(100..=)), Term::Num.new(150))
      q(%Q(not(100..=)), Term::Num.new(1000))

      q(%Q(not(100..<)), Term::Num.new(-1000.456), 0)
      q(%Q(not(100..<)), Term::Num.new(100))
      q(%Q(not(100..<)), Term::Num.new(150))
      q(%Q(not(100..<)), Term::Num.new(1000))
    end

    it "must support not(<number>..=<number>)" do
      q(%Q(not(0..=100)), Term::Num.new(-1000.456), 0)
      q(%Q(not(0..=100)), Term::Num.new(0))
      q(%Q(not(0..=100)), Term::Num.new(80))
      q(%Q(not(0..=100)), Term::Num.new(100))
      q(%Q(not(0..=100)), Term::Num.new(1000), 0)
    end

    it "must support not(<number>..<<number>)" do
      q(%Q(not(0..<100)), Term::Num.new(-1000.456), 0)
      q(%Q(not(0..<100)), Term::Num.new(0))
      q(%Q(not(0..<100)), Term::Num.new(80))
      q(%Q(not(0..<100)), Term::Num.new(100), 0)
      q(%Q(not(0..<100)), Term::Num.new(1000), 0)
    end
  end

  describe "not(< > <= >= /? ..= ..< ...) given anything else" do
    it "must support not(< <number>)" do
      q(%Q(not(< 100)), Term::Str.new("hello world"), 0)
      q(%Q(not(< 100)), Term::Bool.new(true), 0)
      q(%Q(not(< 100)), Term::Dict[], 0)
      q(%Q(not(< 100)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(< 100)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end

    it "must support not(> <number>)" do
      q(%Q(not(> 100)), Term::Str.new("hello world"), 0)
      q(%Q(not(> 100)), Term::Bool.new(true), 0)
      q(%Q(not(> 100)), Term::Dict[], 0)
      q(%Q(not(> 100)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(> 100)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end

    it "must support not(<= <number>)" do
      q(%Q(not(<= 100)), Term::Str.new("hello world"), 0)
      q(%Q(not(<= 100)), Term::Bool.new(true), 0)
      q(%Q(not(<= 100)), Term::Dict[], 0)
      q(%Q(not(<= 100)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(<= 100)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end

    it "must support not(>= <number>)" do
      q(%Q(not(>= 100)), Term::Str.new("hello world"), 0)
      q(%Q(not(>= 100)), Term::Bool.new(true), 0)
      q(%Q(not(>= 100)), Term::Dict[], 0)
      q(%Q(not(>= 100)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(>= 100)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end

    it "must support not(/? <number>)" do
      q(%Q(not(/? 10)), Term::Str.new("hello world"), 0)
      q(%Q(not(/? 10)), Term::Bool.new(true), 0)
      q(%Q(not(/? 10)), Term::Dict[], 0)
      q(%Q(not(/? 10)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(/? 10)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end

    it "must support not(..=<number>) and not(..<<number>)" do
      q(%Q(not(..=100)), Term::Str.new("hello world"), 0)
      q(%Q(not(..=100)), Term::Bool.new(true), 0)
      q(%Q(not(..=100)), Term::Dict[], 0)
      q(%Q(not(..=100)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(..=100)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)

      q(%Q(not(..<100)), Term::Str.new("hello world"), 0)
      q(%Q(not(..<100)), Term::Bool.new(true), 0)
      q(%Q(not(..<100)), Term::Dict[], 0)
      q(%Q(not(..<100)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(..<100)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end

    it "must support not(<number>..=) and not(<number>..<)" do
      q(%Q(not(100..=)), Term::Str.new("hello world"), 0)
      q(%Q(not(100..=)), Term::Bool.new(true), 0)
      q(%Q(not(100..=)), Term::Dict[], 0)
      q(%Q(not(100..=)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(100..=)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)

      q(%Q(not(100..<)), Term::Str.new("hello world"), 0)
      q(%Q(not(100..<)), Term::Bool.new(true), 0)
      q(%Q(not(100..<)), Term::Dict[], 0)
      q(%Q(not(100..<)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(100..<)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end

    it "must support not(<number>..=<number>)" do
      q(%Q(not(0..=100)), Term::Str.new("hello world"), 0)
      q(%Q(not(0..=100)), Term::Bool.new(true), 0)
      q(%Q(not(0..=100)), Term::Dict[], 0)
      q(%Q(not(0..=100)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(0..=100)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end

    it "must support not(<number>..<<number>)" do
      q(%Q(not(0..<100)), Term::Str.new("hello world"), 0)
      q(%Q(not(0..<100)), Term::Bool.new(true), 0)
      q(%Q(not(0..<100)), Term::Dict[], 0)
      q(%Q(not(0..<100)), Term::Dict[Term::Num[1], Term::Num[2]], 0)
      q(%Q(not(0..<100)), Term::Dict[a: Term::Num[1], b: Term::Num[2]], 0)
    end
  end

  describe "misc" do
    it "should handle many same programs" do
      map = Sparse::Map(Int32).new
      map[0...5] = (0...5).map { %Q({ "first_name": string, "last_name": string }) }

      mq(map, Term::Num.new(100))
      mq(map, Term::Dict[first_name: Term::Str.new("John")])
      mq(map, Term::Dict[last_name: Term::Str.new("Doe")])
      mq(map, Term::Dict[first_name: Term::Str.new("John"), last_name: Term::Str.new("Doe")], 0, 1, 2, 3, 4)
      mq(map, Term::Dict[first_name: Term::Str.new("Jane"), last_name: Term::Str.new("Boo")], 0, 1, 2, 3, 4)
      mq(map, Term::Dict[first_name: Term::Num.new(123), last_name: Term::Num.new(456)])
      mq(map, Term::Dict[first_name: Term::Str.new("John"), last_name: Term::Str.new("Doe"), age: Term::Num.new(25)], 0, 1, 2, 3, 4)
    end

    it "should update properly" do
      map = Sparse::Map(Int32).new
      map[0] = "/? 5 > 10"
      map[1] = "/? 5 < 10"
      map[2] = "/? 5"
      map[3] = "10"

      mq(map, Term::Dict[name: Term::Str.new("Jane Doe")])
      mq(map, Term::Num.new(3))
      mq(map, Term::Num.new(33))
      mq(map, Term::Num.new(-33))
      mq(map, Term::Num.new(35), 0, 2)
      mq(map, Term::Num.new(-35), 1, 2)
      mq(map, Term::Num.new(10), 2, 3)

      map[{0, 1, 3}] = {"/? 3 > 10", %Q({ name "Jane Doe" }), "11"}

      mq(map, Term::Dict[name: Term::Str.new("Jane Doe")], 1)
      mq(map, Term::Num.new(3))
      mq(map, Term::Num.new(-33))
      mq(map, Term::Num.new(33), 0)
      mq(map, Term::Num.new(35), 2)
      mq(map, Term::Num.new(-35), 2)
      mq(map, Term::Num.new(10), 2)
      mq(map, Term::Num.new(11), 3)
    end

    it "should handle single-of-many-same update properly" do
      map = Sparse::Map(Int32).new
      map[0...5] = (0...5).map { %Q({ "first_name": string, "last_name": string }) }
      map[2] = %Q({ "first_name": string, "last_name": string, "female": bool })

      mq(map, Term::Num.new(100))
      mq(map, Term::Dict[first_name: Term::Str.new("John")])
      mq(map, Term::Dict[last_name: Term::Str.new("Doe")])
      mq(map, Term::Dict[first_name: Term::Str.new("John"), last_name: Term::Str.new("Doe")], 0, 1, 3, 4)
      mq(map, Term::Dict[first_name: Term::Str.new("jane"), last_name: Term::Str.new("Doe")], 0, 1, 3, 4)
      mq(map, Term::Dict[first_name: Term::Str.new("jane"), last_name: Term::Str.new("Doe"), female: Term::Bool.new(true)], 0, 1, 2, 3, 4)
    end

    it "should be able to query population" do
      map = Sparse::Map(Int32).new
      map[0...10] = (0...10).map { |n| %Q({ "type": "number", "value": #{n} }) }
      map[10...20] = (0...10).map { %Q({ "type": "number", "value": number }) }
      map[20...30] = (0...10).map { %Q({ "first_name": string, "last_name": string }) }

      counter = Counter(Int32).new
      (0...30).each do |x|
        map[Raktor::Term::Dict[type: Raktor::Term::Str.new("number"), value: Raktor::Term::Num.new(x)], counter]
      end

      map[Raktor::Term::Dict[first_name: Raktor::Term::Str.new("John"), last_name: Raktor::Term::Str.new("Doe")], counter]

      # value: number should respond 10 times per every x in 0...30 => 10 * 30
      # value: n should respond 10 times, for x in 0...10 => 10
      # first_name, last_name should respond 10 times => 10
      counter.count.should eq(10 * 30 + 10 + 10)
    end
  end

  describe "#delete" do
    it "must delete keys and assoc programs from map" do
      map = Sparse::Map(Int32).new
      map[0] = %Q("hello")
      map[1] = %Q(100)

      map[Term::Str.new("hello")].should eq([0])
      map[Term::Num.new(100)].should eq([1])
      map.empty?.should be_false

      map.delete(0)

      map[Term::Str.new("hello")].should eq([] of Int32)
      map[Term::Num.new(100)].should eq([1])
      map.empty?.should be_false

      map.delete(1)

      map[Term::Str.new("hello")].should eq([] of Int32)
      map[Term::Num.new(100)].should eq([] of Int32)
      map.empty?.should be_true
    end

    it "must delete with intermediate" do
      map = Sparse::Map(Int32).new
      map[0] = %Q("hello")
      map[1] = %Q(100)
      map[2] = %Q(string)
      map[3] = %Q(number)

      map[Term::Str.new("hello"), Set(Int32).new].should eq(Set{0, 2})
      map[Term::Num.new(100), Set(Int32).new].should eq(Set{1, 3})

      map.delete(0)

      map[Term::Str.new("hello")].should eq([2])
      map[Term::Num.new(100), Set(Int32).new].should eq(Set{1, 3})

      map.delete(1)

      map[Term::Str.new("hello")].should eq([2])
      map[Term::Num.new(100)].should eq([3])

      map.delete(2)

      map[Term::Str.new("hello")].should eq([] of Int32)
      map[Term::Num.new(100)].should eq([3])

      map.delete(3)

      map[Term::Str.new("hello")].should eq([] of Int32)
      map[Term::Num.new(100)].should eq([] of Int32)
      map.empty?.should be_true
    end
  end
end
