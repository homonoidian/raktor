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
      q(%Q(any), Terms::Str.new("hello world"), 0)
      q(%Q(any), Terms::Num.new(123.4), 0)
      q(%Q(any), Terms::Boolean.new(true), 0)
      q(%Q(any), Terms::Dict[], 0)
      q(%Q(any), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(any), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end

    it "should support type string" do
      q(%Q(string), Terms::Str.new("hello world"), 0)
      q(%Q(string), Terms::Num.new(123.4))
      q(%Q(string), Terms::Boolean.new(true))
      q(%Q(string), Terms::Dict[])
      q(%Q(string), Terms::Dict[Terms::Num[1], Terms::Num[2]])
      q(%Q(string), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]])
    end

    it "should support type number" do
      q(%Q(number), Terms::Str.new("hello world"))
      q(%Q(number), Terms::Num.new(123.4), 0)
      q(%Q(number), Terms::Boolean.new(true))
      q(%Q(number), Terms::Dict[])
      q(%Q(number), Terms::Dict[Terms::Num[1], Terms::Num[2]])
      q(%Q(number), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]])
      q(%Q(123_456), Terms::Num.new(123_456), 0)
      q(%Q(123_456), Terms::Num.new(100))
    end

    it "should support type bool" do
      q(%Q(bool), Terms::Str.new("hello world"))
      q(%Q(bool), Terms::Num.new(123.4))
      q(%Q(bool), Terms::Boolean.new(true), 0)
      q(%Q(bool), Terms::Boolean.new(false), 0)
      q(%Q(bool), Terms::Dict[])
      q(%Q(bool), Terms::Dict[Terms::Num[1], Terms::Num[2]])
      q(%Q(bool), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]])
    end

    it "should support type dict" do
      q(%Q(dict), Terms::Str.new("hello world"))
      q(%Q(dict), Terms::Num.new(123.4))
      q(%Q(dict), Terms::Boolean.new(true))
      q(%Q(dict), Terms::Boolean.new(false))
      q(%Q(dict), Terms::Dict[], 0)
      q(%Q(dict), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(dict), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end
  end

  describe "< <= isolated" do
    it "must match number" do
      q(%Q(< 100; <= 100), Terms::Num.new(-100), 0, 1)
      q(%Q(< 100; <= 100), Terms::Num.new(50), 0, 1)
      q(%Q(< 100; <= 100), Terms::Num.new(100), 1)
      q(%Q(< 100; <= 100), Terms::Num.new(150))
    end

    it "must not match other" do
      q(%Q(< 100; <= 100), Terms::Str.new("hello world"))
      q(%Q(< 100; <= 100), Terms::Boolean.new(true))
      q(%Q(< 100; <= 100), Terms::Dict[Terms::Num.new(1), Terms::Num.new(2), Terms::Num.new(3)])
      q(%Q(< 100; <= 100), Terms::Dict[a: Terms::Num.new(1), b: Terms::Num.new(2), c: Terms::Num.new(3)])
    end

    it "must support combination with or" do
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Terms::Num.new(-1000), 0, 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Terms::Num.new(50), 0, 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Terms::Num.new(100), 0, 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Terms::Num.new(400), 0, 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Terms::Num.new(500), 0, 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Terms::Num.new(800), 0, 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Terms::Num.new(1000), 1)
      q(%Q(< 100 or < 500 or < 1000; <= 100 or <= 500 or <= 1000), Terms::Num.new(1500))
    end

    it "must support combination with and" do
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Terms::Num.new(-1000), 0, 1)
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Terms::Num.new(0), 0, 1)
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Terms::Num.new(5), 0, 1)
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Terms::Num.new(10), 1)
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Terms::Num.new(40))
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Terms::Num.new(50))
      q(%Q(< 100 < 50 < 10; <= 100 <= 50 <= 10), Terms::Num.new(1000))
    end

    it "must support merge" do
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Terms::Num.new(-1000), 0, 1, 2, 3, 4, 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Terms::Num.new(50), 0, 1, 2, 3, 4, 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Terms::Num.new(100), 1, 2, 3, 4, 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Terms::Num.new(400), 1, 2, 4, 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Terms::Num.new(500), 2, 4, 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Terms::Num.new(800), 2, 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Terms::Num.new(1000), 5)
      q(%Q(< 100; < 500; < 1000; <= 100; <= 500; <= 1000), Terms::Num.new(1500))
    end

    it "must support alt" do
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Terms::Num.new(-1000), 0, 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Terms::Num.new(50), 0, 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Terms::Num.new(100), 0, 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Terms::Num.new(400), 0, 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Terms::Num.new(500), 0, 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Terms::Num.new(800), 0, 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Terms::Num.new(1000), 1)
      q(%Q(< 100 | 500 | 1000; <= 100 | 500 | 1000), Terms::Num.new(1500))
    end

    it "must support alt merge" do
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Terms::Num.new(-1000), 0, 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Terms::Num.new(50), 0, 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Terms::Num.new(100), 0, 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Terms::Num.new(400), 0, 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Terms::Num.new(500), 0, 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Terms::Num.new(800), 0, 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Terms::Num.new(1000), 1, 2, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Terms::Num.new(1500), 1, 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Terms::Num.new(2000), 3)
      q(%Q(< 100 | 500 | 1000; < 200 | 300 | 2000; <= 100 | 500 | 1000; <= 200 | 300 | 2000), Terms::Num.new(2500))
    end
  end

  describe "> >= isolated" do
    it "must match number" do
      q(%Q(> 100; >= 100), Terms::Num.new(-100))
      q(%Q(> 100; >= 100), Terms::Num.new(50))
      q(%Q(> 100; >= 100), Terms::Num.new(100), 1)
      q(%Q(> 100; >= 100), Terms::Num.new(150), 0, 1)
    end

    it "must not match other" do
      q(%Q(> 100; >= 100), Terms::Str.new("hello world"))
      q(%Q(> 100; >= 100), Terms::Boolean.new(true))
      q(%Q(> 100; >= 100), Terms::Dict[Terms::Num.new(1), Terms::Num.new(2), Terms::Num.new(3)])
      q(%Q(> 100; >= 100), Terms::Dict[a: Terms::Num.new(1), b: Terms::Num.new(2), c: Terms::Num.new(3)])
    end

    it "must support combination with or" do
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Terms::Num.new(-1000))
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Terms::Num.new(50))
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Terms::Num.new(100), 1)
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Terms::Num.new(400), 0, 1)
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Terms::Num.new(500), 0, 1)
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Terms::Num.new(800), 0, 1)
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Terms::Num.new(1000), 0, 1)
      q(%Q(> 100 or > 500 or > 1000; >= 100 or >= 500 or >= 1000), Terms::Num.new(1500), 0, 1)
    end

    it "must support combination with and" do
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Terms::Num.new(-1000))
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Terms::Num.new(0))
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Terms::Num.new(5))
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Terms::Num.new(10))
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Terms::Num.new(40))
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Terms::Num.new(50))
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Terms::Num.new(100), 1)
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Terms::Num.new(101), 0, 1)
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Terms::Num.new(300), 0, 1)
      q(%Q(> 100 > 50 > 10; >= 100 >= 50 >= 10), Terms::Num.new(1000), 0, 1)
    end

    it "must support merge" do
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Terms::Num.new(-1000))
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Terms::Num.new(50))
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Terms::Num.new(100), 3)
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Terms::Num.new(400), 0, 3)
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Terms::Num.new(500), 0, 3, 4)
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Terms::Num.new(800), 0, 1, 3, 4)
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Terms::Num.new(1000), 0, 1, 3, 4, 5)
      q(%Q(> 100; > 500; > 1000; >= 100; >= 500; >= 1000), Terms::Num.new(1500), 0, 1, 2, 3, 4, 5)
    end

    it "must support alt" do
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Terms::Num.new(-1000))
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Terms::Num.new(50))
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Terms::Num.new(100), 1)
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Terms::Num.new(400), 0, 1)
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Terms::Num.new(500), 0, 1)
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Terms::Num.new(800), 0, 1)
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Terms::Num.new(1000), 0, 1)
      q(%Q(> 100 | 500 | 1000; >= 100 | 500 | 1000), Terms::Num.new(1500), 0, 1)
    end

    it "must support alt merge" do
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Terms::Num.new(-1000))
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Terms::Num.new(50))
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Terms::Num.new(100), 2)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Terms::Num.new(400), 0, 1, 2, 3)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Terms::Num.new(500), 0, 1, 2, 3)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Terms::Num.new(800), 0, 1, 2, 3)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Terms::Num.new(1000), 0, 1, 2, 3)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Terms::Num.new(1500), 0, 1, 2, 3)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Terms::Num.new(2000), 0, 1, 2, 3)
      q(%Q(> 100 | 500 | 1000; > 200 | 300 | 2000; >= 100 | 500 | 1000; >= 200 | 300 | 2000), Terms::Num.new(2500), 0, 1, 2, 3)
    end
  end

  describe "/? isolated" do
    it "must match number" do
      q(%Q(/? 10), Terms::Num.new(0), 0)
      q(%Q(/? 10), Terms::Num.new(100), 0)
      q(%Q(/? 10), Terms::Num.new(120), 0)
      q(%Q(/? 10), Terms::Num.new(125))
      q(%Q(/? 10), Terms::Num.new(127))
      q(%Q(/? 10), Terms::Num.new(126))
      q(%Q(/? 10), Terms::Num.new(-100), 0)
      q(%Q(/? 10), Terms::Num.new(-15))
      q(%Q(/? 10), Terms::Num.new(-13))
      q(%Q(/? 10), Terms::Num.new(-1))
    end

    it "must not match any number if arg is 0" do
      q(%Q(/? 0), Terms::Num.new(0))
      q(%Q(/? 0), Terms::Num.new(123))
      q(%Q(/? 0), Terms::Num.new(-100))
    end

    it "must not match other" do
      q(%Q(/? 10), Terms::Str.new("hello world"))
      q(%Q(/? 10), Terms::Boolean.new(true))
      q(%Q(/? 10), Terms::Dict[Terms::Num.new(1), Terms::Num.new(2), Terms::Num.new(3)])
      q(%Q(/? 10), Terms::Dict[a: Terms::Num.new(1), b: Terms::Num.new(2), c: Terms::Num.new(3)])
    end

    it "must support combination with or" do
      q(%Q(/? 5 or /? 15), Terms::Num.new(0), 0)
      q(%Q(/? 5 or /? 15), Terms::Num.new(100), 0)
      q(%Q(/? 5 or /? 15), Terms::Num.new(15), 0)
      q(%Q(/? 5 or /? 15), Terms::Num.new(30), 0)
      q(%Q(/? 5 or /? 15), Terms::Num.new(45), 0)
      q(%Q(/? 5 or /? 15), Terms::Num.new(120), 0)
      q(%Q(/? 5 or /? 15), Terms::Num.new(125), 0)
      q(%Q(/? 5 or /? 15), Terms::Num.new(127))
      q(%Q(/? 5 or /? 15), Terms::Num.new(126))
      q(%Q(/? 5 or /? 15), Terms::Num.new(-100), 0)
      q(%Q(/? 5 or /? 15), Terms::Num.new(-125), 0)
      q(%Q(/? 5 or /? 15), Terms::Num.new(-15), 0)
      q(%Q(/? 5 or /? 15), Terms::Num.new(-13))
      q(%Q(/? 5 or /? 15), Terms::Num.new(-1))
    end

    it "must support combination with and" do
      q(%Q(/? 5 /? 15), Terms::Num.new(0), 0)
      q(%Q(/? 5 /? 15), Terms::Num.new(100))
      q(%Q(/? 5 /? 15), Terms::Num.new(15), 0)
      q(%Q(/? 5 /? 15), Terms::Num.new(30), 0)
      q(%Q(/? 5 /? 15), Terms::Num.new(45), 0)
      q(%Q(/? 5 /? 15), Terms::Num.new(120), 0)
      q(%Q(/? 5 /? 15), Terms::Num.new(125))
      q(%Q(/? 5 /? 15), Terms::Num.new(127))
      q(%Q(/? 5 /? 15), Terms::Num.new(126))
      q(%Q(/? 5 /? 15), Terms::Num.new(-100))
      q(%Q(/? 5 /? 15), Terms::Num.new(-125))
      q(%Q(/? 5 /? 15), Terms::Num.new(-15), 0)
      q(%Q(/? 5 /? 15), Terms::Num.new(-13))
      q(%Q(/? 5 /? 15), Terms::Num.new(-1))
    end

    it "must support alt" do
      q(%Q(/? 5 | 15), Terms::Num.new(0), 0)
      q(%Q(/? 5 | 15), Terms::Num.new(100), 0)
      q(%Q(/? 5 | 15), Terms::Num.new(15), 0)
      q(%Q(/? 5 | 15), Terms::Num.new(30), 0)
      q(%Q(/? 5 | 15), Terms::Num.new(45), 0)
      q(%Q(/? 5 | 15), Terms::Num.new(120), 0)
      q(%Q(/? 5 | 15), Terms::Num.new(125), 0)
      q(%Q(/? 5 | 15), Terms::Num.new(127))
      q(%Q(/? 5 | 15), Terms::Num.new(126))
      q(%Q(/? 5 | 15), Terms::Num.new(-100), 0)
      q(%Q(/? 5 | 15), Terms::Num.new(-125), 0)
      q(%Q(/? 5 | 15), Terms::Num.new(-15), 0)
      q(%Q(/? 5 | 15), Terms::Num.new(-13))
      q(%Q(/? 5 | 15), Terms::Num.new(-1))
    end

    it "must support merge" do
      q(%Q(/? 5; /? 15), Terms::Num.new(0), 0, 1)
      q(%Q(/? 5; /? 15), Terms::Num.new(100), 0)
      q(%Q(/? 5; /? 15), Terms::Num.new(15), 0, 1)
      q(%Q(/? 5; /? 15), Terms::Num.new(30), 0, 1)
      q(%Q(/? 5; /? 15), Terms::Num.new(45), 0, 1)
      q(%Q(/? 5; /? 15), Terms::Num.new(120), 0, 1)
      q(%Q(/? 5; /? 15), Terms::Num.new(125), 0)
      q(%Q(/? 5; /? 15), Terms::Num.new(127))
      q(%Q(/? 5; /? 15), Terms::Num.new(126))
      q(%Q(/? 5; /? 15), Terms::Num.new(-100), 0)
      q(%Q(/? 5; /? 15), Terms::Num.new(-125), 0)
      q(%Q(/? 5; /? 15), Terms::Num.new(-15), 0, 1)
      q(%Q(/? 5; /? 15), Terms::Num.new(-13))
      q(%Q(/? 5; /? 15), Terms::Num.new(-1))
    end

    it "must support alt merge" do
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(-100), 0, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(0), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(3), 1, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(5), 0, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(7))
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(8), 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(15), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(30), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(40), 0, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(45), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(44.5))
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(48), 1, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 | 3 | 2), Terms::Num.new(135), 0, 1, 2, 3)
    end

    it "must support and merge" do
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Terms::Num.new(-100), 0)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Terms::Num.new(0), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Terms::Num.new(3), 1)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Terms::Num.new(5), 0)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Terms::Num.new(7))
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Terms::Num.new(15), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Terms::Num.new(30), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Terms::Num.new(40), 0)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Terms::Num.new(45), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Terms::Num.new(48), 1)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 /? 3), Terms::Num.new(135), 0, 1, 2, 3)
    end

    it "must support or merge" do
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Terms::Num.new(-100), 0, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Terms::Num.new(0), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Terms::Num.new(3), 1, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Terms::Num.new(5), 0, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Terms::Num.new(7))
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Terms::Num.new(8), 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Terms::Num.new(15), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Terms::Num.new(30), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Terms::Num.new(40), 0, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Terms::Num.new(45), 0, 1, 2, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Terms::Num.new(48), 1, 3)
      q(%Q(/? 5; /? 3; /? 5 /? 15; /? 5 or /? 3 or /? 2), Terms::Num.new(135), 0, 1, 2, 3)
    end
  end

  describe "..=Y X..= X..=Y ..<Y X..< X..<Y ..< ..= isolated" do
    it "must support beginless inclusive, exclusve" do
      q(%Q(..=100), Terms::Num.new(-1000.456), 0)
      q(%Q(..=100), Terms::Num.new(30), 0)
      q(%Q(..=100), Terms::Num.new(100), 0)
      q(%Q(..=100), Terms::Num.new(150))

      q(%Q(..<100), Terms::Num.new(-1000.456), 0)
      q(%Q(..<100), Terms::Num.new(30), 0)
      q(%Q(..<100), Terms::Num.new(100))
      q(%Q(..<100), Terms::Num.new(150))
    end

    it "must support endless inclusive, exclusive" do
      q(%Q(100..=), Terms::Num.new(-1000.456))
      q(%Q(100..=), Terms::Num.new(100), 0)
      q(%Q(100..=), Terms::Num.new(150), 0)
      q(%Q(100..=), Terms::Num.new(1000), 0)

      q(%Q(100..<), Terms::Num.new(-1000.456))
      q(%Q(100..<), Terms::Num.new(100), 0)
      q(%Q(100..<), Terms::Num.new(150), 0)
      q(%Q(100..<), Terms::Num.new(1000), 0)
    end

    it "must support inclusive" do
      q(%Q(0..=100), Terms::Num.new(-1000.456))
      q(%Q(0..=100), Terms::Num.new(0), 0)
      q(%Q(0..=100), Terms::Num.new(80), 0)
      q(%Q(0..=100), Terms::Num.new(100), 0)
      q(%Q(0..=100), Terms::Num.new(1000))
    end

    it "must support exclusive" do
      q(%Q(0..<100), Terms::Num.new(-1000.456))
      q(%Q(0..<100), Terms::Num.new(0), 0)
      q(%Q(0..<100), Terms::Num.new(80), 0)
      q(%Q(0..<100), Terms::Num.new(100))
      q(%Q(0..<100), Terms::Num.new(1000))
    end

    it "must support combination with and" do
      q(%Q(0..=100 50..=80), Terms::Num.new(-1000.456))
      q(%Q(0..=100 50..=80), Terms::Num.new(0))
      q(%Q(0..=100 50..=80), Terms::Num.new(30))
      q(%Q(0..=100 50..=80), Terms::Num.new(50), 0)
      q(%Q(0..=100 50..=80), Terms::Num.new(70), 0)
      q(%Q(0..=100 50..=80), Terms::Num.new(80), 0)
      q(%Q(0..=100 50..=80), Terms::Num.new(90))
      q(%Q(0..=100 50..=80), Terms::Num.new(100))
      q(%Q(0..=100 50..=80), Terms::Num.new(150))

      q(%Q(0..<100 50..<80), Terms::Num.new(-1000.456))
      q(%Q(0..<100 50..<80), Terms::Num.new(0))
      q(%Q(0..<100 50..<80), Terms::Num.new(30))
      q(%Q(0..<100 50..<80), Terms::Num.new(50), 0)
      q(%Q(0..<100 50..<80), Terms::Num.new(70), 0)
      q(%Q(0..<100 50..<80), Terms::Num.new(80))
      q(%Q(0..<100 50..<80), Terms::Num.new(90))
      q(%Q(0..<100 50..<80), Terms::Num.new(100))
      q(%Q(0..<100 50..<80), Terms::Num.new(150))
    end

    it "must support combination with or" do
      q(%Q(0..=100 or 50..=80), Terms::Num.new(-1000.456))
      q(%Q(0..=100 or 50..=80), Terms::Num.new(0), 0)
      q(%Q(0..=100 or 50..=80), Terms::Num.new(30), 0)
      q(%Q(0..=100 or 50..=80), Terms::Num.new(50), 0)
      q(%Q(0..=100 or 50..=80), Terms::Num.new(70), 0)
      q(%Q(0..=100 or 50..=80), Terms::Num.new(80), 0)
      q(%Q(0..=100 or 50..=80), Terms::Num.new(90), 0)
      q(%Q(0..=100 or 50..=80), Terms::Num.new(100), 0)
      q(%Q(0..=100 or 50..=80), Terms::Num.new(150))

      q(%Q(0..<100 or 50..<80), Terms::Num.new(-1000.456))
      q(%Q(0..<100 or 50..<80), Terms::Num.new(0), 0)
      q(%Q(0..<100 or 50..<80), Terms::Num.new(30), 0)
      q(%Q(0..<100 or 50..<80), Terms::Num.new(50), 0)
      q(%Q(0..<100 or 50..<80), Terms::Num.new(70), 0)
      q(%Q(0..<100 or 50..<80), Terms::Num.new(80), 0)
      q(%Q(0..<100 or 50..<80), Terms::Num.new(90), 0)
      q(%Q(0..<100 or 50..<80), Terms::Num.new(100))
      q(%Q(0..<100 or 50..<80), Terms::Num.new(150))
    end

    it "must support merge" do
      q(%Q(0..=100; 50..=80), Terms::Num.new(-1000.456))
      q(%Q(0..=100; 50..=80), Terms::Num.new(0), 0)
      q(%Q(0..=100; 50..=80), Terms::Num.new(30), 0)
      q(%Q(0..=100; 50..=80), Terms::Num.new(50), 0, 1)
      q(%Q(0..=100; 50..=80), Terms::Num.new(70), 0, 1)
      q(%Q(0..=100; 50..=80), Terms::Num.new(80), 0, 1)
      q(%Q(0..=100; 50..<80), Terms::Num.new(80), 0)
      q(%Q(0..=100; 50..=80), Terms::Num.new(90), 0)
      q(%Q(0..=100; 50..=80), Terms::Num.new(100), 0)
      q(%Q(0..<100; 50..=80), Terms::Num.new(100))
      q(%Q(0..=100; 50..=80), Terms::Num.new(150))
    end

    it "must combine with type well" do
      q(%Q(0..=100 number), Terms::Num.new(-1000.456))
      q(%Q(0..=100 number), Terms::Num.new(0), 0)
      q(%Q(0..=100 number), Terms::Num.new(30), 0)
      q(%Q(0..=100 number), Terms::Num.new(100), 0)
      q(%Q(0..<100 number), Terms::Num.new(100))
      q(%Q(0..=100 number), Terms::Num.new(150))

      q(%Q(0..=100 or number), Terms::Num.new(-1000.456), 0)
      q(%Q(0..=100 or number), Terms::Num.new(0), 0)
      q(%Q(0..=100 or number), Terms::Num.new(30), 0)
      q(%Q(0..=100 or number), Terms::Num.new(100), 0)
      q(%Q(0..<100 or number), Terms::Num.new(100), 0)
      q(%Q(0..=100 or number), Terms::Num.new(150), 0)

      q(%Q(number; 0..=100), Terms::Num.new(-1000.456), 0)
      q(%Q(number; 0..=100), Terms::Num.new(0), 0, 1)
      q(%Q(number; 0..=100), Terms::Num.new(30), 0, 1)
      q(%Q(number; 0..=100), Terms::Num.new(100), 0, 1)
      q(%Q(number; 0..<100), Terms::Num.new(100), 0)
      q(%Q(number; 0..=100), Terms::Num.new(150), 0)
    end

    it "must combine with exact well" do
      q(%Q(123 or -100 or 0..=100), Terms::Num.new(-1000.456))
      q(%Q(123 or -100 or 0..=100), Terms::Num.new(-100), 0)
      q(%Q(123 or -100 or 0..=100), Terms::Num.new(-50))
      q(%Q(123 or -100 or 0..=100), Terms::Num.new(0), 0)
      q(%Q(123 or -100 or 0..=100), Terms::Num.new(50), 0)
      q(%Q(123 or -100 or 0..=100), Terms::Num.new(100), 0)
      q(%Q(123 or -100 or 0..<100), Terms::Num.new(100))
      q(%Q(123 or -100 or 0..=100), Terms::Num.new(105))
      q(%Q(123 or -100 or 0..=100), Terms::Num.new(123), 0)
      q(%Q(123 or -100 or 0..=100), Terms::Num.new(155))

      q(%Q(123; -100; 50; 0..=100), Terms::Num.new(-1000.456))
      q(%Q(123; -100; 50; 0..=100), Terms::Num.new(-100), 1)
      q(%Q(123; -100; 50; 0..=100), Terms::Num.new(-50))
      q(%Q(123; -100; 50; 0..=100), Terms::Num.new(0), 3)
      q(%Q(123; -100; 50; 0..=100), Terms::Num.new(50), 2, 3)
      q(%Q(123; -100; 50; 0..=100), Terms::Num.new(100), 3)
      q(%Q(123; -100; 50; 0..<100), Terms::Num.new(100))
      q(%Q(123; -100; 50; 0..=100), Terms::Num.new(105))
      q(%Q(123; -100; 50; 0..=100), Terms::Num.new(123), 0)
      q(%Q(123; -100; 50; 0..=100), Terms::Num.new(155))
    end
  end

  describe "list dict" do
    it "must match exact" do
      q(%Q([1, 2, 3]), Terms::Dict[Terms::Num.new(1), Terms::Num.new(2), Terms::Num.new(3)], 0)
      q(%Q([1, 2, 3]), Terms::Dict[Terms::Num.new(100), Terms::Num.new(2), Terms::Num.new(3)])
      q(%Q([1, 2, 3]), Terms::Dict[Terms::Num.new(1), Terms::Num.new(200), Terms::Num.new(3)])
      q(%Q([1, 2, 3]), Terms::Dict[Terms::Num.new(1), Terms::Num.new(2), Terms::Num.new(300)])
      q(%Q([1, 2, 3]), Terms::Dict[Terms::Num.new(1), Terms::Num.new(2)])
      q(%Q([1, 2, 3]), Terms::Dict[Terms::Num.new(1)])
      q(%Q([1, 2, 3]), Terms::Dict[Terms::Num.new(2)])
      q(%Q([1, 2, 3]), Terms::Dict[Terms::Num.new(3)])
      q(%Q([1, 2, 3]), Terms::Dict[Terms::Num.new(123)])
      q(%Q([1, 2, 3]), Terms::Dict[])
    end

    it "must match if more than specified" do
      q(%Q([1, 2, 3]), Terms::Dict[Terms::Num.new(1), Terms::Num.new(2), Terms::Num.new(3), Terms::Num.new(4)], 0)
      q(%Q([1, 2, 3]), Terms::Dict[Terms::Num.new(1), Terms::Num.new(2), Terms::Num.new(3), Terms::Str.new("foobar")], 0)
      # ...
    end

    it "must work with conditions and nesting" do
      q1 = %Q([string, /? 100 > 100 not(200), [number, number]])
      q(q1, Terms::Num.new(300))
      q(q1, Terms::Dict[])
      q(q1, Terms::Dict[Terms::Str.new("hello")])
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(300)])
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(300), Terms::Dict[]])
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(300), Terms::Dict[Terms::Num.new(123)]])
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(300), Terms::Dict[Terms::Num.new(123), Terms::Num.new(456)]], 0)
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(10), Terms::Dict[Terms::Num.new(123), Terms::Num.new(456)]])
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(64), Terms::Dict[Terms::Num.new(123), Terms::Num.new(456)]])
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(100), Terms::Dict[Terms::Num.new(123), Terms::Num.new(456)]])
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(1234), Terms::Dict[Terms::Num.new(123), Terms::Num.new(456)]])
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(200), Terms::Dict[Terms::Num.new(123), Terms::Num.new(456)]])
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(300), Terms::Dict[Terms::Num.new(123), Terms::Num.new(456)]], 0)
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(400), Terms::Dict[Terms::Num.new(123), Terms::Num.new(456)]], 0)
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(1000), Terms::Dict[Terms::Num.new(123), Terms::Num.new(456)]], 0)
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(300), Terms::Dict[Terms::Num.new(123), Terms::Str.new("hello")]])
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(300), Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(123)]])
      q(q1, Terms::Dict[Terms::Num.new(123), Terms::Num.new(300), Terms::Dict[Terms::Num.new(123), Terms::Num.new(456)]])
    end

    it "must combine and merge well" do
      q1 = %Q([number, number] [100, 200])
      q(q1, Terms::Num.new(100))
      q(q1, Terms::Num.new(200))
      q(q1, Terms::Dict[])
      q(q1, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(456)])
      q(q1, Terms::Dict[Terms::Num.new(123), Terms::Num.new(456)])
      q(q1, Terms::Dict[Terms::Num.new(100), Terms::Num.new(456)])
      q(q1, Terms::Dict[Terms::Num.new(100), Terms::Str.new("world")])
      q(q1, Terms::Dict[Terms::Num.new(123), Terms::Num.new(200)])
      q(q1, Terms::Dict[Terms::Num.new(100), Terms::Num.new(200)], 0)
      q(q1, Terms::Dict[Terms::Num.new(100), Terms::Num.new(200), Terms::Str.new("hello world")], 0)

      q2 = %Q([]; []; [] or [100]; [1, 2, 3]; [number, number, number]; [number or string, number, number]; dict; [string])
      q(q2, Terms::Num.new(100))
      q(q2, Terms::Dict[], 0, 1, 2, 6)
      q(q2, Terms::Dict[Terms::Str.new("hello")], 0, 1, 2, 6, 7)
      q(q2, Terms::Dict[Terms::Num.new(100)], 0, 1, 2, 6)
      q(q2, Terms::Dict[Terms::Num.new(1), Terms::Num.new(2), Terms::Num.new(3)], 0, 1, 2, 3, 4, 5, 6)
      q(q2, Terms::Dict[Terms::Num.new(1), Terms::Num.new(100), Terms::Num.new(3)], 0, 1, 2, 4, 5, 6)
      q(q2, Terms::Dict[Terms::Str.new("hello"), Terms::Num.new(2), Terms::Num.new(3)], 0, 1, 2, 5, 6, 7)

      q3 = %Q([/? 100 > 100 not(200)] or number; [/? 200 > 300 not(300)] or string or 456)
      q(q3, Terms::Num.new(123), 0)
      q(q3, Terms::Str.new("hello"), 1)
      q(q3, Terms::Num.new(456), 0, 1)
      q(q3, Terms::Dict[])
      q(q3, Terms::Dict[Terms::Num.new(0)])
      q(q3, Terms::Dict[Terms::Num.new(123)])
      q(q3, Terms::Dict[Terms::Num.new(100)])
      q(q3, Terms::Dict[Terms::Num.new(200)])
      q(q3, Terms::Dict[Terms::Num.new(300)], 0)
      q(q3, Terms::Dict[Terms::Num.new(400)], 0, 1)
      q(q3, Terms::Dict[Terms::Num.new(500)], 0)
      q(q3, Terms::Dict[Terms::Num.new(600)], 0, 1)
      q(q3, Terms::Dict[Terms::Num.new(-500)])
      q(q3, Terms::Dict[Terms::Num.new(-600)])
    end
  end

  describe "dict" do
    it "must access 01 with overlaps" do
      q1 = %Q({ name: "John Doe", age /? 100 }; { name: "Jane Doe", age 0..=100 /? 5, foo: string}; { foo: string, bar: number }; { bar: string })

      q(q1, Terms::Dict[name: Terms::Str.new("John Doe")])
      q(q1, Terms::Dict[name: Terms::Str.new("John Doe"), foo: Terms::Str.new("hello world")])
      q(q1, Terms::Dict[name: Terms::Str.new("John Doe"), foo: Terms::Str.new("hello world"), bar: Terms::Num.new(123)], 2)
      q(q1, Terms::Dict[name: Terms::Str.new("John Doe"), foo: Terms::Str.new("hello world"), bar: Terms::Str.new("hello bar")], 3)
      q(q1, Terms::Dict[
        name: Terms::Str.new("John Doe"),
        age: Terms::Num.new(24),
        foo: Terms::Str.new("hello world"),
        bar: Terms::Str.new("hello bar"),
      ], 3)
      q(q1, Terms::Dict[
        name: Terms::Str.new("John Doe"),
        age: Terms::Num.new(24),
        foo: Terms::Str.new("hello world"),
        bar: Terms::Num.new(123),
      ], 2)
      q(q1, Terms::Dict[
        name: Terms::Str.new("John Doe"),
        age: Terms::Num.new(200),
        foo: Terms::Str.new("hello world"),
        bar: Terms::Str.new("hello bar"),
      ], 0, 3)
      q(q1, Terms::Dict[
        name: Terms::Str.new("John Doe"),
        age: Terms::Num.new(200),
        foo: Terms::Str.new("hello world"),
        bar: Terms::Num.new(123),
      ], 0, 2)
      q(q1, Terms::Dict[
        name: Terms::Str.new("Jane Doe"),
        age: Terms::Num.new(-100),
      ])
      q(q1, Terms::Dict[
        name: Terms::Str.new("Jane Doe"),
        age: Terms::Num.new(200),
      ])
      q(q1, Terms::Dict[
        name: Terms::Str.new("Jane Doe"),
        age: Terms::Num.new(53),
      ])
      q(q1, Terms::Dict[
        name: Terms::Str.new("Jane Doe"),
        age: Terms::Num.new(50),
      ])
      q(q1, Terms::Dict[
        name: Terms::Str.new("Jane Doe"),
        age: Terms::Num.new(50),
        foo: Terms::Num.new(50),
      ])
      q(q1, Terms::Dict[
        name: Terms::Str.new("Jane Doe"),
        age: Terms::Num.new(50),
        foo: Terms::Str.new("hello world"),
      ], 1)
      q(q1, Terms::Dict[
        name: Terms::Str.new("Jane Doe"),
        age: Terms::Num.new(53),
        foo: Terms::Str.new("hello world"),
      ])
      q(q1, Terms::Dict[
        name: Terms::Str.new("Jane Doe"),
        age: Terms::Num.new(0),
        foo: Terms::Str.new("hello world"),
      ], 1)
      q(q1, Terms::Dict[
        name: Terms::Str.new("Jane Doe"),
        age: Terms::Num.new(100),
        foo: Terms::Str.new("hello world"),
      ], 1)
      q(q1, Terms::Dict[
        name: Terms::Str.new("Jane Doe"),
        age: Terms::Num.new(100),
        foo: Terms::Str.new("hello world"),
        bar: Terms::Num.new(123),
      ], 1, 2)
      q(q1, Terms::Dict[
        name: Terms::Str.new("Jane Doe"),
        age: Terms::Num.new(100),
        foo: Terms::Str.new("hello world"),
        bar: Terms::Str.new("bye world"),
      ], 1, 3)
      q(q1, Terms::Dict[
        name: Terms::Str.new("John Doe"),
        age: Terms::Num.new(100),
        foo: Terms::Str.new("hello world"),
        bar: Terms::Str.new("bye world"),
      ], 0, 3)
    end

    it "must access 2" do
      q1 = %Q({ name: "John Doe", age /? 100 }; { name: "Jane Doe", age 0..=100 /? 5, foo: string}; { foo: string, bar: number }; { bar: string })

      q(q1, Terms::Dict[foo: Terms::Str.new("hello world"), bar: Terms::Num.new(123)], 2)
      q(q1, Terms::Dict[foo: Terms::Str.new("hello world")])
    end

    it "must access 3" do
      q1 = %Q({ name: "John Doe", age /? 100 }; { name: "Jane Doe", age 0..=100 /? 5, foo: string}; { foo: string, bar: number }; { bar: string })

      q(q1, Terms::Dict[bar: Terms::Str.new("fooze")], 3)
      q(q1, Terms::Dict[foo: Terms::Str.new("hello world"), bar: Terms::Str.new("foobrazaur")], 3)
      q(q1, Terms::Dict[bar: Terms::Num.new(123)])
    end
  end

  describe "basic not(...)" do
    it "must work for basic exacts" do
      q(%Q(not(123)), Terms::Num.new(100), 0)
      q(%Q(not(123)), Terms::Str.new("hello world"), 0)
      q(%Q(not(123)), Terms::Num.new(123))
      q(%Q(not(123)), Terms::Num.new(123.456), 0)
      q(%Q(not(123)), Terms::Num.new(-123), 0)

      q(%Q(not("hello world")), Terms::Str.new("foobar"), 0)
      q(%Q(not("hello world")), Terms::Num.new(123), 0)
      q(%Q(not("hello world")), Terms::Str.new("hello world"))
      q(%Q(not("hello world")), Terms::Str.new("hello worldo"), 0)

      q(%Q(not(true)), Terms::Boolean.new(false), 0)
      q(%Q(not(true)), Terms::Boolean.new(true))
      q(%Q(not(true)), Terms::Str.new(""), 0)
      q(%Q(not(true)), Terms::Num.new(0), 0)

      q(%Q(not(false)), Terms::Boolean.new(false))
      q(%Q(not(false)), Terms::Boolean.new(true), 0)
      q(%Q(not(false)), Terms::Str.new(""), 0)
      q(%Q(not(false)), Terms::Num.new(0), 0)
    end

    it "must allow to negate type any" do
      q(%Q(not(any)), Terms::Str.new("hello world"))
      q(%Q(not(any)), Terms::Num.new(123.4))
      q(%Q(not(any)), Terms::Boolean.new(true))
      q(%Q(not(any)), Terms::Dict[])
      q(%Q(not(any)), Terms::Dict[Terms::Num[1], Terms::Num[2]])
      q(%Q(not(any)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]])
    end

    it "must allow to negate type string" do
      q(%Q(not(string)), Terms::Str.new("hello world"))
      q(%Q(not(string)), Terms::Num.new(123.4), 0)
      q(%Q(not(string)), Terms::Boolean.new(true), 0)
      q(%Q(not(string)), Terms::Dict[], 0)
      q(%Q(not(string)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(string)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end

    it "must allow to negate type number" do
      q(%Q(not(number)), Terms::Str.new("hello world"), 0)
      q(%Q(not(number)), Terms::Num.new(123.4))
      q(%Q(not(number)), Terms::Boolean.new(true), 0)
      q(%Q(not(number)), Terms::Dict[], 0)
      q(%Q(not(number)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(number)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end

    it "must allow to negate type bool" do
      q(%Q(not(bool)), Terms::Str.new("hello world"), 0)
      q(%Q(not(bool)), Terms::Num.new(123.4), 0)
      q(%Q(not(bool)), Terms::Boolean.new(true))
      q(%Q(not(bool)), Terms::Dict[], 0)
      q(%Q(not(bool)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(bool)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end

    it "must allow to negate type dict" do
      q(%Q(not(dict)), Terms::Str.new("hello world"), 0)
      q(%Q(not(dict)), Terms::Num.new(123.4), 0)
      q(%Q(not(dict)), Terms::Boolean.new(true), 0)
      q(%Q(not(dict)), Terms::Dict[])
      q(%Q(not(dict)), Terms::Dict[Terms::Num[1], Terms::Num[2]])
      q(%Q(not(dict)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]])
    end

    it "must handle nesting well" do
      q(%Q(not(not(123))), Terms::Num.new(100))
      q(%Q(not(not(123))), Terms::Str.new("hello world"))
      q(%Q(not(not(123))), Terms::Num.new(123), 0)
      q(%Q(not(not(123))), Terms::Num.new(123.456))
      q(%Q(not(not(123))), Terms::Num.new(-123))

      q(%Q(not(not("hello world"))), Terms::Str.new("foobar"))
      q(%Q(not(not("hello world"))), Terms::Num.new(123))
      q(%Q(not(not("hello world"))), Terms::Str.new("hello world"), 0)
      q(%Q(not(not("hello world"))), Terms::Str.new("hello worldo"))

      q(%Q(not(not(true))), Terms::Boolean.new(false))
      q(%Q(not(not(true))), Terms::Boolean.new(true), 0)
      q(%Q(not(not(true))), Terms::Str.new(""))
      q(%Q(not(not(true))), Terms::Num.new(0))

      q(%Q(not(not(false))), Terms::Boolean.new(false), 0)
      q(%Q(not(not(false))), Terms::Boolean.new(true))
      q(%Q(not(not(false))), Terms::Str.new(""))
      q(%Q(not(not(false))), Terms::Num.new(0))

      q(%Q(not(not(not(123)))), Terms::Num.new(100), 0)
      q(%Q(not(not(not(123)))), Terms::Str.new("hello world"), 0)
      q(%Q(not(not(not(123)))), Terms::Num.new(123))
      q(%Q(not(not(not(123)))), Terms::Num.new(123.456), 0)
      q(%Q(not(not(not(123)))), Terms::Num.new(-123), 0)

      q(%Q(not(not(not("hello world")))), Terms::Str.new("foobar"), 0)
      q(%Q(not(not(not("hello world")))), Terms::Num.new(123), 0)
      q(%Q(not(not(not("hello world")))), Terms::Str.new("hello world"))
      q(%Q(not(not(not("hello world")))), Terms::Str.new("hello worldo"), 0)

      q(%Q(not(not(not(true)))), Terms::Boolean.new(false), 0)
      q(%Q(not(not(not(true)))), Terms::Boolean.new(true))
      q(%Q(not(not(not(true)))), Terms::Str.new(""), 0)
      q(%Q(not(not(not(true)))), Terms::Num.new(0), 0)

      q(%Q(not(not(not(false)))), Terms::Boolean.new(false))
      q(%Q(not(not(not(false)))), Terms::Boolean.new(true), 0)
      q(%Q(not(not(not(false)))), Terms::Str.new(""), 0)
      q(%Q(not(not(not(false)))), Terms::Num.new(0), 0)
    end

    it "must support exact dict" do
      q1 = %Q(not({ name string, age /? 2 }))
      q(q1, Terms::Num.new(123), 0)
      q(q1, Terms::Boolean.new(true), 0)
      q(q1, Terms::Str.new("hello"), 0)
      q(q1, Terms::Dict[], 0)
      q(q1, Terms::Dict[name: Terms::Str.new("John Doe")], 0)
      q(q1, Terms::Dict[name: Terms::Str.new("John Doe"), age: Terms::Num.new(123)], 0)
      q(q1, Terms::Dict[name: Terms::Str.new("John Doe"), age: Terms::Num.new(124)])
      q(q1, Terms::Dict[name: Terms::Str.new("John Doe"), age: Terms::Num.new(124), foo: Terms::Str.new("bar")])
      q(q1, Terms::Dict[name: Terms::Num.new(123), age: Terms::Num.new(124), foo: Terms::Str.new("bar")], 0)
      q(q1, Terms::Dict[name: Terms::Str.new("John Doe"), age: Terms::Num.new(124.5), foo: Terms::Str.new("bar")], 0)
    end
  end

  describe "not(< > <= >= /? ..= ..< ...) given a number" do
    it "must support not(< <number>)" do
      q(%Q(not(< 100)), Terms::Num.new(-123))
      q(%Q(not(< 100)), Terms::Num.new(100), 0)
      q(%Q(not(< 100)), Terms::Num.new(123), 0)
    end

    it "must support not(> <number>)" do
      q(%Q(not(> 100)), Terms::Num.new(-123), 0)
      q(%Q(not(> 100)), Terms::Num.new(100), 0)
      q(%Q(not(> 100)), Terms::Num.new(123))
    end

    it "must support not(<= <number>)" do
      q(%Q(not(<= 100)), Terms::Num.new(-123))
      q(%Q(not(<= 100)), Terms::Num.new(100))
      q(%Q(not(<= 100)), Terms::Num.new(123), 0)
    end

    it "must support not(>= <number>)" do
      q(%Q(not(>= 100)), Terms::Num.new(-123), 0)
      q(%Q(not(>= 100)), Terms::Num.new(100))
      q(%Q(not(>= 100)), Terms::Num.new(123))
    end

    it "must support not(/? <number>)" do
      q(%Q(not(/? 10)), Terms::Num.new(-123), 0)
      q(%Q(not(/? 10)), Terms::Num.new(-100))
      q(%Q(not(/? 10)), Terms::Num.new(-15), 0)
      q(%Q(not(/? 10)), Terms::Num.new(0))
      q(%Q(not(/? 10)), Terms::Num.new(10))
      q(%Q(not(/? 10)), Terms::Num.new(13), 0)
      q(%Q(not(/? 10)), Terms::Num.new(15), 0)
      q(%Q(not(/? 10)), Terms::Num.new(100))
    end

    it "must support not(..=<number>) and not(..<<number>)" do
      q(%Q(not(..=100)), Terms::Num.new(-1000.456))
      q(%Q(not(..=100)), Terms::Num.new(30))
      q(%Q(not(..=100)), Terms::Num.new(100))
      q(%Q(not(..=100)), Terms::Num.new(150), 0)

      q(%Q(not(..<100)), Terms::Num.new(-1000.456))
      q(%Q(not(..<100)), Terms::Num.new(30))
      q(%Q(not(..<100)), Terms::Num.new(100), 0)
      q(%Q(not(..<100)), Terms::Num.new(150), 0)
    end

    it "must support not(<number>..=) and not(<number>..<)" do
      q(%Q(not(100..=)), Terms::Num.new(-1000.456), 0)
      q(%Q(not(100..=)), Terms::Num.new(100))
      q(%Q(not(100..=)), Terms::Num.new(150))
      q(%Q(not(100..=)), Terms::Num.new(1000))

      q(%Q(not(100..<)), Terms::Num.new(-1000.456), 0)
      q(%Q(not(100..<)), Terms::Num.new(100))
      q(%Q(not(100..<)), Terms::Num.new(150))
      q(%Q(not(100..<)), Terms::Num.new(1000))
    end

    it "must support not(<number>..=<number>)" do
      q(%Q(not(0..=100)), Terms::Num.new(-1000.456), 0)
      q(%Q(not(0..=100)), Terms::Num.new(0))
      q(%Q(not(0..=100)), Terms::Num.new(80))
      q(%Q(not(0..=100)), Terms::Num.new(100))
      q(%Q(not(0..=100)), Terms::Num.new(1000), 0)
    end

    it "must support not(<number>..<<number>)" do
      q(%Q(not(0..<100)), Terms::Num.new(-1000.456), 0)
      q(%Q(not(0..<100)), Terms::Num.new(0))
      q(%Q(not(0..<100)), Terms::Num.new(80))
      q(%Q(not(0..<100)), Terms::Num.new(100), 0)
      q(%Q(not(0..<100)), Terms::Num.new(1000), 0)
    end
  end

  describe "not(< > <= >= /? ..= ..< ...) given anything else" do
    it "must support not(< <number>)" do
      q(%Q(not(< 100)), Terms::Str.new("hello world"), 0)
      q(%Q(not(< 100)), Terms::Boolean.new(true), 0)
      q(%Q(not(< 100)), Terms::Dict[], 0)
      q(%Q(not(< 100)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(< 100)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end

    it "must support not(> <number>)" do
      q(%Q(not(> 100)), Terms::Str.new("hello world"), 0)
      q(%Q(not(> 100)), Terms::Boolean.new(true), 0)
      q(%Q(not(> 100)), Terms::Dict[], 0)
      q(%Q(not(> 100)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(> 100)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end

    it "must support not(<= <number>)" do
      q(%Q(not(<= 100)), Terms::Str.new("hello world"), 0)
      q(%Q(not(<= 100)), Terms::Boolean.new(true), 0)
      q(%Q(not(<= 100)), Terms::Dict[], 0)
      q(%Q(not(<= 100)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(<= 100)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end

    it "must support not(>= <number>)" do
      q(%Q(not(>= 100)), Terms::Str.new("hello world"), 0)
      q(%Q(not(>= 100)), Terms::Boolean.new(true), 0)
      q(%Q(not(>= 100)), Terms::Dict[], 0)
      q(%Q(not(>= 100)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(>= 100)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end

    it "must support not(/? <number>)" do
      q(%Q(not(/? 10)), Terms::Str.new("hello world"), 0)
      q(%Q(not(/? 10)), Terms::Boolean.new(true), 0)
      q(%Q(not(/? 10)), Terms::Dict[], 0)
      q(%Q(not(/? 10)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(/? 10)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end

    it "must support not(..=<number>) and not(..<<number>)" do
      q(%Q(not(..=100)), Terms::Str.new("hello world"), 0)
      q(%Q(not(..=100)), Terms::Boolean.new(true), 0)
      q(%Q(not(..=100)), Terms::Dict[], 0)
      q(%Q(not(..=100)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(..=100)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)

      q(%Q(not(..<100)), Terms::Str.new("hello world"), 0)
      q(%Q(not(..<100)), Terms::Boolean.new(true), 0)
      q(%Q(not(..<100)), Terms::Dict[], 0)
      q(%Q(not(..<100)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(..<100)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end

    it "must support not(<number>..=) and not(<number>..<)" do
      q(%Q(not(100..=)), Terms::Str.new("hello world"), 0)
      q(%Q(not(100..=)), Terms::Boolean.new(true), 0)
      q(%Q(not(100..=)), Terms::Dict[], 0)
      q(%Q(not(100..=)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(100..=)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)

      q(%Q(not(100..<)), Terms::Str.new("hello world"), 0)
      q(%Q(not(100..<)), Terms::Boolean.new(true), 0)
      q(%Q(not(100..<)), Terms::Dict[], 0)
      q(%Q(not(100..<)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(100..<)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end

    it "must support not(<number>..=<number>)" do
      q(%Q(not(0..=100)), Terms::Str.new("hello world"), 0)
      q(%Q(not(0..=100)), Terms::Boolean.new(true), 0)
      q(%Q(not(0..=100)), Terms::Dict[], 0)
      q(%Q(not(0..=100)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(0..=100)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end

    it "must support not(<number>..<<number>)" do
      q(%Q(not(0..<100)), Terms::Str.new("hello world"), 0)
      q(%Q(not(0..<100)), Terms::Boolean.new(true), 0)
      q(%Q(not(0..<100)), Terms::Dict[], 0)
      q(%Q(not(0..<100)), Terms::Dict[Terms::Num[1], Terms::Num[2]], 0)
      q(%Q(not(0..<100)), Terms::Dict[a: Terms::Num[1], b: Terms::Num[2]], 0)
    end
  end

  describe "misc" do
    it "should handle many same programs" do
      map = Sparse::Map(Int32).new
      map[0...5] = (0...5).map { %Q({ "first_name": string, "last_name": string }) }

      mq(map, Terms::Num.new(100))
      mq(map, Terms::Dict[first_name: Terms::Str.new("John")])
      mq(map, Terms::Dict[last_name: Terms::Str.new("Doe")])
      mq(map, Terms::Dict[first_name: Terms::Str.new("John"), last_name: Terms::Str.new("Doe")], 0, 1, 2, 3, 4)
      mq(map, Terms::Dict[first_name: Terms::Str.new("Jane"), last_name: Terms::Str.new("Boo")], 0, 1, 2, 3, 4)
      mq(map, Terms::Dict[first_name: Terms::Num.new(123), last_name: Terms::Num.new(456)])
      mq(map, Terms::Dict[first_name: Terms::Str.new("John"), last_name: Terms::Str.new("Doe"), age: Terms::Num.new(25)], 0, 1, 2, 3, 4)
    end

    it "should update properly" do
      map = Sparse::Map(Int32).new
      map[0] = "/? 5 > 10"
      map[1] = "/? 5 < 10"
      map[2] = "/? 5"
      map[3] = "10"

      mq(map, Terms::Dict[name: Terms::Str.new("Jane Doe")])
      mq(map, Terms::Num.new(3))
      mq(map, Terms::Num.new(33))
      mq(map, Terms::Num.new(-33))
      mq(map, Terms::Num.new(35), 0, 2)
      mq(map, Terms::Num.new(-35), 1, 2)
      mq(map, Terms::Num.new(10), 2, 3)

      map[{0, 1, 3}] = {"/? 3 > 10", %Q({ name "Jane Doe" }), "11"}

      mq(map, Terms::Dict[name: Terms::Str.new("Jane Doe")], 1)
      mq(map, Terms::Num.new(3))
      mq(map, Terms::Num.new(-33))
      mq(map, Terms::Num.new(33), 0)
      mq(map, Terms::Num.new(35), 2)
      mq(map, Terms::Num.new(-35), 2)
      mq(map, Terms::Num.new(10), 2)
      mq(map, Terms::Num.new(11), 3)
    end

    it "should handle single-of-many-same update properly" do
      map = Sparse::Map(Int32).new
      map[0...5] = (0...5).map { %Q({ "first_name": string, "last_name": string }) }
      map[2] = %Q({ "first_name": string, "last_name": string, "female": bool })

      mq(map, Terms::Num.new(100))
      mq(map, Terms::Dict[first_name: Terms::Str.new("John")])
      mq(map, Terms::Dict[last_name: Terms::Str.new("Doe")])
      mq(map, Terms::Dict[first_name: Terms::Str.new("John"), last_name: Terms::Str.new("Doe")], 0, 1, 3, 4)
      mq(map, Terms::Dict[first_name: Terms::Str.new("jane"), last_name: Terms::Str.new("Doe")], 0, 1, 3, 4)
      mq(map, Terms::Dict[first_name: Terms::Str.new("jane"), last_name: Terms::Str.new("Doe"), female: Terms::Boolean.new(true)], 0, 1, 2, 3, 4)
    end

    it "should be able to query population" do
      map = Sparse::Map(Int32).new
      map[0...10] = (0...10).map { |n| %Q({ "type": "number", "value": #{n} }) }
      map[10...20] = (0...10).map { %Q({ "type": "number", "value": number }) }
      map[20...30] = (0...10).map { %Q({ "first_name": string, "last_name": string }) }

      counter = Counter(Int32).new
      (0...30).each do |x|
        map[Terms::Dict[type: Terms::Str.new("number"), value: Terms::Num.new(x)], counter]
      end

      map[Terms::Dict[first_name: Terms::Str.new("John"), last_name: Terms::Str.new("Doe")], counter]

      # value: number should respond 10 times per every x in 0...30 => 10 * 30
      # value: n should respond 10 times, for x in 0...10 => 10
      # first_name, last_name should respond 10 times => 10
      counter.count.should eq(10 * 30 + 10 + 10)
    end

    it "supports and + not on dicts" do
      q1 = %Q({ a: 1 } { b: 2 } not({ c: 3 }))

      q(q1, Terms::Num.new(123))
      q(q1, Terms::Dict[a: Terms::Num.new(1)])
      q(q1, Terms::Dict[a: Terms::Num.new(1), b: Terms::Num.new(2)], 0)
      q(q1, Terms::Dict[a: Terms::Num.new(100), b: Terms::Num.new(2)])
      q(q1, Terms::Dict[a: Terms::Num.new(1), b: Terms::Num.new(200)])
      q(q1, Terms::Dict[a: Terms::Num.new(1), b: Terms::Num.new(2), c: Terms::Num.new(3)])
      q(q1, Terms::Dict[a: Terms::Num.new(1), b: Terms::Num.new(2), c: Terms::Num.new(4)], 0)
    end

    it "supports upsert" do
      map = Sparse::Map(Int32).new
      map[0] = "number"
      map[1] = "string"

      map.upsert(2, "/? 10") do |q|
        mq(q, Terms::Num.new(123))
        mq(q, Terms::Num.new(100), 2)
        mq(q, Terms::Str.new("hello world"))
      end

      mq(map, Terms::Num.new(123), 0)
      mq(map, Terms::Num.new(100), 0, 2)
      mq(map, Terms::Str.new("hello world"), 1)
    end

    it "supports not with string" do
      q(%Q(string not("" or "[" or "]")), Terms::Str["hello"], 0)
      q(%Q(string not("" or "[" or "]")), Terms::Str[""])
      q(%Q(string not("" or "[" or "]")), Terms::Str["["])
      q(%Q(string not("" or "[" or "]")), Terms::Str["]"])
      q(%Q(string not("" or "[" or "]")), Terms::Str["123["], 0)
      q(%Q(string not("" or "[" or "]")), Terms::Str["]456"], 0)
      q(%Q({ x: string not("" or "[" or "]") }), Terms::Dict[x: Term::Str["hello"], y: Terms::Boolean[true]], 0)
      q(%Q({ x: string not("" or "[" or "]") }), Terms::Dict[x: Term::Str[""], y: Terms::Boolean[true]])
      q(%Q({ x: string not("" or "[" or "]") }), Terms::Dict[x: Term::Str["["], y: Terms::Boolean[true]])
      q(%Q({ x: string not("" or "[" or "]") }), Terms::Dict[x: Term::Str["]"], y: Terms::Boolean[true]])
    end
  end

  describe "#delete" do
    it "must delete keys and assoc programs from map" do
      map = Sparse::Map(Int32).new
      map[0] = %Q("hello")
      map[1] = %Q(100)

      map[Terms::Str.new("hello")].should eq([0])
      map[Terms::Num.new(100)].should eq([1])
      map.empty?.should be_false

      map.delete(0)

      map[Terms::Str.new("hello")].should eq([] of Int32)
      map[Terms::Num.new(100)].should eq([1])
      map.empty?.should be_false

      map.delete(1)

      map[Terms::Str.new("hello")].should eq([] of Int32)
      map[Terms::Num.new(100)].should eq([] of Int32)
      map.empty?.should be_true
    end

    it "must delete with intermediate" do
      map = Sparse::Map(Int32).new
      map[0] = %Q("hello")
      map[1] = %Q(100)
      map[2] = %Q(string)
      map[3] = %Q(number)

      map[Terms::Str.new("hello"), Set(Int32).new].should eq(Set{0, 2})
      map[Terms::Num.new(100), Set(Int32).new].should eq(Set{1, 3})

      map.delete(0)

      map[Terms::Str.new("hello")].should eq([2])
      map[Terms::Num.new(100), Set(Int32).new].should eq(Set{1, 3})

      map.delete(1)

      map[Terms::Str.new("hello")].should eq([2])
      map[Terms::Num.new(100)].should eq([3])

      map.delete(2)

      map[Terms::Str.new("hello")].should eq([] of Int32)
      map[Terms::Num.new(100)].should eq([3])

      map.delete(3)

      map[Terms::Str.new("hello")].should eq([] of Int32)
      map[Terms::Num.new(100)].should eq([] of Int32)
      map.empty?.should be_true
    end
  end
end
