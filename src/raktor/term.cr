module Raktor
  struct TermIR
    include Cannon::Auto

    def initialize(@typeid : UInt8, @arg : String | Float64? = nil, @children = [] of TermIR)
    end

    def to_term
      case @typeid
      when Term::TypeID::NUM
        Terms::Num.new(@arg.as(Float64))
      when Term::TypeID::STR
        Terms::Str.new(@arg.as(String))
      when Term::TypeID::BOOL
        Terms::Boolean.new(!@arg.nil?)
      when Term::TypeID::DICT
        dict = Terms::Dict.new
        0.step(to: @children.size, by: 2, exclusive: true) do |k|
          kt = @children[k].to_term
          vt = @children[k + 1].to_term
          if kt.is_a?(Terms::Str) || kt.is_a?(Terms::Num)
            dict = dict.putattr(kt, vt)
          end
        end
        dict
      else
        raise ArgumentError.new
      end
    end
  end

  module Terms
  end

  abstract class Term
    include Terms

    module TypeID
      NUM  = 0u8
      STR  = 1u8
      BOOL = 2u8
      DICT = 3u8
    end

    def self.[](value)
      new(value)
    end

    def as_d
      as(Dict)
    end

    def as_n
      as(Num)
    end

    def as_s
      as(Str)
    end

    def as_b
      as(Boolean)
    end

    def to_cannon_io(io)
      to_ir.to_cannon_io(io)
    end

    def self.from_cannon_io(io)
      TermIR.from_cannon_io(io).to_term
    end
  end

  class Terms::Num < Term
    getter value

    def initialize(@value : Float64)
    end

    def typeid
      TypeID::NUM
    end

    def to_ir
      TermIR.new(typeid, @value)
    end

    def +(other : Num)
      Num.new(value + other.value)
    end

    def succ
      self + Num[1]
    end

    def -(other : Num)
      Num.new(value - other.value)
    end

    def pred
      self - Num[1]
    end

    def *(other : Num)
      Num.new(value * other.value)
    end

    def /(other : Num)
      Num.new(value / other.value)
    end

    def div_by?(other : Num) : Bool
      value % other.value == 0
    end

    def <(other : Num)
      value < other.value
    end

    def to_s(io)
      io << value
    end

    def_equals_and_hash @value
  end

  class Terms::Str < Term
    getter value : String

    def initialize(value)
      @value = value.to_s
    end

    def typeid
      TypeID::STR
    end

    def to_ir
      TermIR.new(typeid, @value)
    end

    def to_s(io)
      value.dump(io)
    end

    def_equals_and_hash @value
  end

  class Terms::Boolean < Term
    getter value

    def initialize(@value : Bool)
    end

    def typeid
      TypeID::BOOL
    end

    def to_ir
      TermIR.new(typeid, @value ? 0.0 : nil)
    end

    def to_s(io)
      io << value
    end

    def_equals_and_hash @value
  end

  class Terms::Dict < Term
    getter value

    def initialize(@value = {} of Term => Term)
    end

    def typeid
      TypeID::DICT
    end

    def to_ir
      children = @value.each_with_object([] of TermIR) do |(k, v), irs|
        irs << k.to_ir
        irs << v.to_ir
      end
      TermIR.new(typeid, children: children)
    end

    def self.[](hash : Hash(Term, Term) = {} of Term => Term)
      new(hash.as(Hash(Term, Term)))
    end

    def self.[](*items : Term)
      new(items.map_with_index { |item, index| {Num.new(index).as(Term), item.as(Term)} }.to_h)
    end

    def self.[](**kvs : Term)
      dict = new
      kvs.each do |k, v|
        dict = dict.putattr(Str.new(k.to_s), v)
      end
      dict
    end

    def getattr?(k : Term)
      @value[k]?
    end

    def getattr(k : Term)
      @value[k]
    end

    def putattr(k : Term, v : Term)
      @value[k] = v
      self
    end

    macro method_missing(call)
      @value[Str.new({{call.id.stringify}})]
    end

    def to_s(io)
      io << "{" << @value.join(", ") { |k, v| "#{k}: #{v}" } << "}"
    end

    def_equals_and_hash @value
  end
end
