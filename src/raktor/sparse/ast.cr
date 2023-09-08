module Raktor::Sparse
  class CompileError < Exception
  end

  module AST::Node
    abstract def compile(chain : Chain, book : RuleBook) : Label

    # If possible converts this node to an array of `Float64`s. Returns
    # the array, or raises `CompileError` if impossible to convert.
    def to_f64s
      raise CompileError.new("expected a number or a choice of numbers, not: #{self}")
    end
  end

  # AST node for a number literal, such as `1.23`, `-100_000`, or `10`.
  class AST::Num
    include Node

    def initialize(@value : Float64)
    end

    def initialize(value : String)
      initialize(value.to_f64)
    end

    def to_f64s
      [@value]
    end

    def compile(chain : Chain, book : RuleBook) : Label
      chain.append(Gate::IsNum.new)
      chain.append(Gate::Exact.new(Term::Num.new(@value)))
      chain.append(book.newlabel)
    end

    def to_s(io)
      io << @value
    end
  end

  class AST::Str
    include Node

    def initialize(@value : String)
    end

    def compile(chain : Chain, book : RuleBook) : Label
      chain.append(Gate::IsStr.new)
      chain.append(Gate::Exact.new(Term::Str.new(@value)))
      chain.append(book.newlabel)
    end

    def to_s(io)
      @value.dump(io)
    end
  end

  class AST::Boolean
    include Node

    def initialize(@value : Bool)
    end

    def compile(chain : Chain, book : RuleBook) : Label
      chain.append(Gate::IsBool.new)
      chain.append(Gate::Exact.new(Term::Bool.new(@value)))
      chain.append(book.newlabel)
    end

    def to_s(io)
      io << @value
    end
  end

  class AST::Id
    include Node

    def initialize(@value : String)
    end

    def compile(chain : Chain, book : RuleBook) : Label
      case @value
      when "any"
      when "string" then chain.append(Gate::IsStr.new)
      when "number" then chain.append(Gate::IsNum.new)
      when "bool"   then chain.append(Gate::IsBool.new)
      when "dict"   then chain.append(Gate::IsDict.new)
      else
        raise CompileError.new("undefined symbol: #{@value}")
      end

      chain.append(book.newlabel)
    end

    def to_s(io)
      io << @value
    end
  end

  struct AST::Dict
    include Node

    def initialize(@pairs : Array(KV))
    end

    def compile(chain : Chain, book : RuleBook) : Label
      chain.append(Gate::IsDict.new)

      if @pairs.empty?
        return chain.append(book.newlabel)
      end

      elems = Chain.new(Chain::Axis::Y)
      chain.append(elems)

      book.combine(@pairs, Rule::Comb::And) do |pair|
        elems.append(elem = Chain.new)
        pair.compile(elem, book)
      end
    end

    def to_s(io)
      io << "{" << @pairs.join(", ") << "}"
    end
  end

  class AST::KV
    include Node

    def initialize(@key : Term::Dict::Key, @constraint : Node)
    end

    def compile(chain : Chain, book : RuleBook) : Label
      chain.append(Gate::Attr.new(@key))

      @constraint.compile(chain, book)
    end

    def to_s(io)
      io << (@key.is_a?(String) ? "\"#{@key}\"" : @key) << ": " << @constraint
    end
  end

  struct AST::Constraint::AllPass
    include Node

    def compile(chain : Chain, book : RuleBook) : Label
      chain.append(book.newlabel)
    end

    def to_s(io)
      io << "pass"
    end
  end

  class AST::Constraint::Satisfies
    include Node

    def initialize(@lhs : Node, @rhs : Node)
    end

    def compile(chain : Chain, book : RuleBook) : Label
      book.combine({@lhs, @rhs}, Rule::Comb::And, &.compile(chain, book))
    end

    def to_s(io)
      io << @lhs << " & " << @rhs
    end
  end

  class AST::Constraint::Choose
    include Node

    def initialize(@lhs : Node, @rhs : Node)
    end

    def to_f64s
      @lhs.to_f64s + @rhs.to_f64s
    end

    def compile(chain : Chain, book : RuleBook) : Label
      raise CompileError.new("can use '|' only as an argument to '<', '>', '<=', '>=', or '/?'")
    end

    def to_s(io)
      io << "(" << @lhs << " | " << @rhs << ")"
    end
  end

  class AST::Constraint::Or
    include Node

    def initialize(@lhs : Node, @rhs : Node)
    end

    def compile(chain : Chain, book : RuleBook) : Label
      options = Chain.new(Chain::Axis::Y)
      chain.append(options)

      book.combine({@lhs, @rhs}, Rule::Comb::Or) do |operand|
        option = Chain.new
        options.append(option)
        operand.compile(option, book)
      end
    end

    def to_s(io)
      io << "(" << @lhs << " or " << @rhs << ")"
    end
  end

  class AST::Constraint::DivBy
    include Node

    def initialize(@arg : Node)
    end

    def compile(chain : Chain, book : RuleBook) : Label
      chain.append(Gate::IsNum.new)

      options = Chain.new(Chain::Axis::Y)
      chain.append(options)

      book.combine(@arg.to_f64s, Rule::Comb::Or) do |f64|
        option = Chain.new
        options.append(option)

        option.append(Gate::DivBy.new(f64))
        option.append(book.newlabel)
      end
    end

    def to_s(io)
      io << "/? " << @arg
    end
  end

  class AST::Constraint::Not
    include Node

    def initialize(@arg : Node)
    end

    def compile(chain : Chain, book : RuleBook) : Label
      book.combine({@arg}, Rule::Comb::Not, &.compile(chain, book))
    end

    def to_s(io)
      io << "not(" << @arg << ")"
    end
  end

  class AST::Constraint::Cmp
    include Node

    enum Kind
      Lt
      Gt
      Lte
      Gte
    end

    def initialize(@kind : Kind, @arg : Node)
    end

    def compile(chain : Chain, book : RuleBook) : Label
      chain.append(Gate::IsNum.new)

      options = Chain.new(Chain::Axis::Y)
      chain.append(options)

      book.combine(@arg.to_f64s, Rule::Comb::Or) do |f64|
        option = Chain.new
        options.append(option)

        case @kind
        in .lt?  then option.append(Gate::Lt.new(f64))
        in .gt?  then option.append(Gate::Gt.new(f64))
        in .lte? then option.append(Gate::Lte.new(f64))
        in .gte? then option.append(Gate::Gte.new(f64))
        end

        option.append(book.newlabel)
      end
    end

    def to_s(io)
      io << @kind << " " << @arg
    end
  end

  struct AST::Constraint::InRange
    include Node

    def initialize(@range : Range(Float64?, Float64?))
    end

    def compile(chain : Chain, book : RuleBook) : Label
      chain.append(Gate::IsNum.new)

      b = @range.begin
      e = @range.end

      chain.append(Gate::Gte.new(b)) if b
      chain.append(@range.exclusive? ? Gate::Lt.new(e) : Gate::Lte.new(e)) if e
      chain.append(book.newlabel)
    end

    def to_s(io)
      io << @range
    end
  end
end
