abstract struct Raktor::Term
  module TypeID
    NUM  = 0
    STR  = 1
    BOOL = 2
    DICT = 3
  end

  def self.[](value)
    new(value)
  end

  struct Num < Term
    getter value

    def initialize(@value : Float64)
    end

    def typeid
      TypeID::NUM
    end

    def <(other : Num)
      value < other.value
    end

    def to_s(io)
      io << value
    end

    def_equals_and_hash @value
  end

  struct Str < Term
    getter value

    def initialize(@value : String)
    end

    def typeid
      TypeID::STR
    end

    def to_s(io)
      value.dump(io)
    end

    def_equals_and_hash @value
  end

  struct Bool < Term
    getter value

    def initialize(@value : ::Bool)
    end

    def typeid
      TypeID::BOOL
    end

    def to_s(io)
      io << value
    end

    def_equals_and_hash @value
  end

  struct Dict < Term
    alias Key = Float64 | String

    getter value

    def initialize(@value = {} of Key => Term)
    end

    def typeid
      TypeID::DICT
    end

    def self.[](hash : Hash(Key, Term) = {} of Key => Term)
      new(hash.as(Hash(Key, Term)))
    end

    def self.[](*items : Term)
      new(items.map_with_index { |item, index| {index.to_f64.as(Key), item.as(Term)} }.to_h)
    end

    def self.[](**kvs : Term)
      hash = {} of Key => Term
      kvs.each do |k, v|
        hash[k.to_s.as(Key)] = v
      end
      new(hash)
    end

    def []?(k : Num | Str)
      @value[k.value]?
    end

    def []?(k)
      nil
    end

    def to_s(io)
      io << "{" << @value.join(", ") { |k, v| "#{k}: #{v}" } << "}"
    end

    def_equals_and_hash @value
  end
end
