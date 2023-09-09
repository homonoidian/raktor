module Raktor::Sparse
  class Parser
    include AST

    # Base class of exceptions raised by the sensor parser.
    class Error < Exception
    end

    @token : Token?

    def initialize(source : String)
      @lexer = Lexer.new(source)
    end

    # Raises an error with the given *message*.
    private def die(message)
      raise Error.new(message)
    end

    # Matches and returns the token ahead, nil if none or if failed
    # to match.
    private def ahead? : Token?
      @lexer.ahead?
    end

    # Returns the current token, or nil if peeking end-of-input. If you
    # need to peek and advance you should use `thru`.
    private def peek? : Token?
      @token ||= ahead?
    end

    # Replaces the current token with the next token, returns
    # the current token. Dies if at end-of-input.
    private def thru : Token
      die("unexpected end-of-input") unless current = peek?

      @token = ahead?

      current
    end

    # Conditional `thru`. If the block returns `true`, same as `thru`;
    # if `false` is returned this method in turn returns nil. On end-
    # of-input this method also returns nil.
    private def thru?(& : Token::Type -> Bool) : Token?
      return unless token = peek?
      return unless yield token.type

      thru
    end

    # Same as `thru?` but dies if the block returns `false`.
    private def expect(&block : Token::Type -> Bool)
      die("unexpected end-of-input") unless token = peek?
      unless yield type = token.type
        die("unexpected token: #{type}")
      end

      thru
    end

    # Captures the state of the parser and returns a proc to restore it.
    private def save : ->
      token, position = @token, @lexer.position

      ->{ @token, @lexer.position = token, position }
    end

    # Parses a delimited list of items.
    #
    # ```text
    # items(O, S, C, &item) ::= O [item {S item}] C
    # ```
    private def items?(
      opened_by : Token::Type,
      separated_by : Token::Type,
      closed_by : Token::Type,
      & : -> T?
    ) : Array(T)? forall T
      return unless thru? { |type| type == opened_by }

      items = [] of T

      if head = yield
        items << head
        while thru? { |type| type == separated_by } && (item = yield)
          items << item
        end
      end

      expect { |type| type == closed_by }

      items
    end

    # Yields token of the given *prefix* if it was matched and nil
    # otherwise; if the block returns nil restores the parser state to
    # that before calling `maybe?`. Returns whatever the block returns.
    private def maybe?(prefix : Token::Type, & : Token? -> T?) : T? forall T
      restore = save

      unless result = yield thru? { |tt| tt == prefix }
        restore.call
      end

      result
    end

    # Parses *rule* or a list of *rule* choices. Returns nil if there
    # is none at the current position.
    #
    # ```text
    # choice(rule) ::= rule {"|" rule}
    # ```
    private def choice?(&rule : -> Node?)
      return unless l = yield
      return l unless thru?(&.pipe?)

      unless r = choice?(&rule)
        die("expected an argument to follow '|', as in `1 | 2`")
      end

      Constraint::Choose.new(l, r)
    end

    # Parses a number literal or a range. Returns nil if there is no
    # match at the current position.
    #
    # *range* is a toggle to enable/disable range parsing since in a
    # declarative, category-matching context a range is also a number.
    #
    # ```text
    # number ::= NUMBER [("..=" | "..<") NUMBER]
    # ```
    private def number?(range = false)
      b = thru?(&.number?)
      unless range && ((inclusive = thru?(&.dotdot_eq?)) || thru?(&.dotdot_lt?))
        return unless b
        return Num.new(b.content)
      end
      e = thru?(&.number?)

      b_f64 = b.content.to_f64 if b
      ef_64 = e.content.to_f64 if e

      Constraint::InRange.new(inclusive ? b_f64..ef_64 : b_f64...ef_64)
    end

    # Parses a numeric constraint. Returns nil if there is no numeric
    # constraint at the current position.
    #
    # ```text
    # numeric ::= ("/?" | "<" | ">" | "<=" | ">=") choice(number)
    # ```
    private def numeric?
      return unless op = thru? { |tt| tt.div_by? || tt.lt? || tt.gt? || tt.lte? || tt.gte? }

      unless arg = choice? { number? }
        die("expected a number to follow '#{op}', as in `#{op} 100`")
      end

      case op.type
      when .div_by? then Constraint::DivBy.new(arg)
      when .lt?     then Constraint::Cmp.new(Constraint::Cmp::Kind::Lt, arg)
      when .gt?     then Constraint::Cmp.new(Constraint::Cmp::Kind::Gt, arg)
      when .lte?    then Constraint::Cmp.new(Constraint::Cmp::Kind::Lte, arg)
      when .gte?    then Constraint::Cmp.new(Constraint::Cmp::Kind::Gte, arg)
      else
        raise "BUG: unreachable"
      end
    end

    # Parses an expression.
    #
    # ```text
    # expression ::= number
    #              | string
    #              | boolean
    #              | id
    #              | dict
    #              | list
    #              | "(" constraint ")"
    #              | "not" ("(" constraint ")" | number | numeric)
    # ```
    private def expression?
      if thru?(&.not?)
        if thru?(&.lpar?) && (arg = constraint?)
          expect(&.rpar?)
        elsif arg = number?
        elsif arg = numeric?
        else
          die("expected an argument to not()")
        end

        return Constraint::Not.new(arg).as(Node?)
      end

      if thru?(&.lpar?)
        unless node = constraint?
          die("expected an expression")
        end
        expect(&.rpar?)
        return node
      end

      return unless token = peek?

      case token.type
      when .string? then node = Str.new(token.content)
      when .true?   then node = Boolean.new(true)
      when .false?  then node = Boolean.new(false)
      when .id?     then node = Id.new(token.content)
      else
        return dict? || list? || number?(range: true)
      end

      thru

      node
    end

    # Parses a constraint match. Returns nil if there is no match at
    # the current position.
    #
    # ```text
    # match ::= numeric | expression
    # ```
    private def match?
      numeric? || expression?
    end

    # Parses a "satisfies" (implicit "and") constraint. Returns nil if
    # there is no "satisfies" constraint at the current position.
    #
    # ```text
    # satisfies ::= match [satisfies]
    # ```
    private def satisfies?
      (l = match?) && (r = satisfies?) ? Constraint::Satisfies.new(l, r) : l
    end

    # Parses an "or" junction. Returns nil if there is no "or" junction
    # at the current position.
    #
    # ```text
    # or ::= satisfies ["or" or]
    # ```
    private def or?
      return unless l = satisfies?
      return l unless thru?(&.or?)

      unless r = or?
        die("expected an expression, like so: `1 or 2`")
      end

      Constraint::Or.new(l, r)
    end

    # Toplevel constraint rule.
    #
    # ```text
    # constraint ::= or
    # ```
    private def constraint?
      or?
    end

    # Parses the key of a key-value pair. Returns nil if no key is
    # found at the current position.
    #
    # ```text
    # key ::= id | string
    # ```
    private def key?
      return unless token = thru? { |type| type.id? || type.string? }

      token.content
    end

    # Parses a key-value pair. Returns nil if no key-value pair is
    # found at the current position.
    #
    # ```text
    # kvpair ::= key [":"] constraint
    # ```
    private def kvpair?
      return unless key = key?

      thru?(&.colon?)

      unless constraint = constraint?
        die("expected an constraint, found none")
      end

      KV.new(Term::Str.new(key), constraint)
    end

    # Parses a dictionary. Returns nil if no dictionary is found at
    # the current position.
    #
    # ```text
    # dict ::= "{" [kvpair {"," kvpair}] "}"
    # ```
    private def dict? : Dict?
      return unless pairs = items?(
                      Token::Type::LCURLY,
                      Token::Type::COMMA,
                      Token::Type::RCURLY
                    ) { kvpair?.as?(KV) }

      Dict.new(pairs)
    end

    # Parses a list. Returns nil if no list is found at the current position.
    # Note that lists are just syntactic sugar for dictionaries with iota
    # integer keys.
    #
    # ```text
    # list ::= "[" [constraint {"," constraint}] "]"
    # ```
    private def list? : Dict?
      return unless items = items?(
                      Token::Type::LSQB,
                      Token::Type::COMMA,
                      Token::Type::RSQB
                    ) { constraint?.as?(Node) }

      Dict.new(items.map_with_index { |item, index| KV.new(Term::Num.new(index), item) })
    end

    # Parses a toplevel expression. If no expression the "all pass"
    # constraint is returned.
    def top : Node
      constraint? || Constraint::AllPass.new
    end

    # Returns the `AST` corresponding to the given *source*. May
    # raise `Error` if *source* is in some way malformed.
    def self.ast(source : String)
      sparse = new(source)
      sparse.top
    end
  end
end
