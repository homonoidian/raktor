module Raktor::Sparse
  # Represents a token of the input stream.
  record Token, type : Type, source : String, byte_range : Range(Int32, Int32) do
    # Lists the available types of tokens.
    enum Type
      LT
      LTE
      GT
      GTE
      COLON
      COMMA
      DIV_BY
      PIPE
      LSQB
      RSQB
      LCURLY
      RCURLY
      LPAR
      RPAR
      DOTDOT_EQ
      DOTDOT_LT
      ID
      STRING
      NUMBER
      TRUE
      FALSE
      NOT
      OR
    end

    # Returns the string content corresponding to this token.
    def content
      source.byte_slice(byte_range)
    end

    def to_s(io)
      io << "<Token type=" << @type << " content='" << content << "'>"
    end
  end

  struct Lexer
    private enum State : UInt8
      START
      END
      LABR
      RABR
      DOT
      DOTDOT
      ALNUM
      DIGITS
      NUMBER
      NUMBER_DOT
      SLASH
      SIGNLIKE
      STRING
      ESCAPE
    end

    def initialize(@string : String)
      @reader = Char::Reader.new(@string)
    end

    # Holds the position of the current character.
    def position : Int32
      @reader.pos
    end

    # :ditto:
    def position=(other : Int32)
      @reader.pos = other
    end

    # Returns whether this lexer's string offset by *start*, starts
    # with *other*.
    private def starts_with?(other : String, start : Int32)
      a = Char::Reader.new(other)
      b = Char::Reader.new(@string, pos: start)

      while a.has_next?
        return false unless a.current_char == b.current_char
        a.next_char
        b.next_char
      end

      true
    end

    # Returns the token ahead, or nil if there is no valid token ahead.
    def ahead? : Token?
      type = nil
      state = State::START
      anchor = @reader.pos

      while true
        chr = @reader.current_char

        case state
        in .end?
          @reader.next_char
          break
        in .start?
          case chr
          when ' ', '\n', '\r', '\t'
            anchor += 1
            @reader.next_char
          when ':' then type, state = Token::Type::COLON, State::END
          when ',' then type, state = Token::Type::COMMA, State::END
          when '|' then type, state = Token::Type::PIPE, State::END
          when '[' then type, state = Token::Type::LSQB, State::END
          when ']' then type, state = Token::Type::RSQB, State::END
          when '{' then type, state = Token::Type::LCURLY, State::END
          when '}' then type, state = Token::Type::RCURLY, State::END
          when '(' then type, state = Token::Type::LPAR, State::END
          when ')' then type, state = Token::Type::RPAR, State::END
          when '.'
            state = State::DOT
            @reader.next_char
          when '+', '-'
            state = State::SIGNLIKE
            @reader.next_char
          when '/'
            state = State::SLASH
            @reader.next_char
          when '<'
            type, state = Token::Type::LT, State::LABR
            @reader.next_char
          when '>'
            type, state = Token::Type::GT, State::RABR
            @reader.next_char
          when 'a'..'z', 'A'..'Z', '_'
            type, state = Token::Type::ID, State::ALNUM
            @reader.next_char
          when '0'..'9'
            type, state = Token::Type::NUMBER, State::NUMBER
            @reader.next_char
          when '"'
            type, state = Token::Type::STRING, State::STRING
            @reader.next_char
          else
            break
          end
        in .signlike?
          case chr
          when '0'..'9'
            type, state = Token::Type::NUMBER, State::NUMBER
            @reader.next_char
          else
            break
          end
        in .labr?
          case chr
          when '=' then type, state = Token::Type::LTE, State::END
          else
            break
          end
        in .rabr?
          case chr
          when '=' then type, state = Token::Type::GTE, State::END
          else
            break
          end
        in .dot?
          case chr
          when '.'
            state = State::DOTDOT
            @reader.next_char
          else
            break
          end
        in .dotdot?
          case chr
          when '<' then type, state = Token::Type::DOTDOT_LT, State::END
          when '=' then type, state = Token::Type::DOTDOT_EQ, State::END
          else
            break
          end
        in .alnum?
          case chr
          when 'a'..'z', 'A'..'Z', '_', '0'..'9'
            @reader.next_char
          else
            case
            when starts_with?("or", start: anchor)
              type = Token::Type::OR
            when starts_with?("not", start: anchor)
              type = Token::Type::NOT
            when starts_with?("true", start: anchor)
              type = Token::Type::TRUE
            when starts_with?("false", start: anchor)
              type = Token::Type::FALSE
            end
            break
          end
        in .number?
          case chr
          when '0'..'9', '_'
            @reader.next_char
          when '.'
            state = State::NUMBER_DOT
            @reader.next_char
          else
            break
          end
        in .number_dot?
          case chr
          when '0'..'9'
            state = State::DIGITS
          when '.'
            # If .. is encountered back off before the first dot.
            @reader.previous_char
            break
          else
            break
          end
        in .digits?
          case chr
          when '0'..'9', '_'
            @reader.next_char
          else
            break
          end
        in .string?
          case chr
          when '"'
            state = State::END
          when '\\'
            state = State::ESCAPE
            @reader.next_char
          else
            unless @reader.has_next?
              raise Error.new("unterminated string literal")
            end
            @reader.next_char
          end
        in .escape?
          state = State::STRING
          unless @reader.has_next?
            raise Error.new("unterminated escape sequence")
          end
          @reader.next_char
        in .slash?
          case chr
          when '?' then type, state = Token::Type::DIV_BY, State::END
          else
            raise Error.new("did you mean '/?'?")
          end
        end
      end

      return unless type

      b = anchor
      e = @reader.pos - 1

      if type.string?
        # Remove opening and closing quotes from string literals.
        b += 1
        e -= 1
      end

      Token.new(type, @string, b..e)
    end
  end
end
