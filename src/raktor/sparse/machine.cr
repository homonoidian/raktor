module Raktor::Sparse::Machine
  # Lists the available `VM` opcodes.
  enum Opcode : UInt8
    # Jump to #0 if the content of the main register A is a number.
    NUMJ

    # Jump to #0 if the content of the main register A is a string.
    STRJ

    # Jump to #0 if the content of the main register A is a boolean.
    BOOLJ

    # Jump to #0 if the content of the main register A is a dictionary.
    DICTJ

    # Load constant at #0 to the auxillary register B.
    LDB

    # Set the main register A to the term popped from the term stack.
    POP

    # Jump to #0 if the content of the main register A is divisible
    # by the content of the auxillary register B.
    #
    # Assumes A and B are numbers, does no checks.
    DIVBYJ

    # Jump to #0 if the content of the main register A is greater than
    # the content of the auxillary register B.
    #
    # Assumes A and B are numbers, does no checks.
    GTJ

    # Jump to #0 if the content of the main register A is greater than
    # or equal to the content of the auxillary register B.
    #
    # Assumes A and B are numbers, does no checks.
    GTEJ

    # Jump to #0 if the content of the main register A is less than
    # the content of the auxillary register B.
    #
    # Assumes A and B are numbers, does no checks.
    LTJ

    # Jump to #0 if the content of the main register A is less than
    # or equal to the content of the auxillary register B.
    #
    # Assumes A and B are numbers, does no checks.
    LTEJ

    # Unconditionally jump to #0.
    J

    # Jump to matching entry in jump table #0. Continue if found no match.
    JT

    # If A has attribute B, push A onto the term stack, set A to the
    # value of the attribute, and jump to #0. If A has no attribute
    # B, continue.
    #
    # Assumes A is a dictionary, does no checks.
    ATTRJ

    # Signal match of label set #0.
    MATCH

    # Optimized `MATCH #0; POP; J #1`.
    MATCHPOPJ

    # Optimized `MATCH #0; [POP]; HLT`.
    MATCHLT

    # Halt the virtual machine.
    HLT
  end

  # Represents a `VM` instruction.
  #
  # *opcode* is the instruction's opcode.
  #
  # *a0* is the instruction's first argument. What it means or points
  # to (and whether it is used at all) depends on the opcode.
  #
  # *a1* is the instruction's second argument. What it means or points
  # to (and whether it is used at all) depends on the opcode.
  record Instr, opcode : Opcode, a0 : Int32, a1 : Int32 do
    def to_s(io)
      io << opcode << " 0x" << a0.to_s(16, precision: 4) << " 0x" << a1.to_s(16, precision: 4)
    end
  end

  # Sparse Machine intermediate representation. Stores and manages constant
  # pools, jumptables, and label sets. Also hold the tape with instructions.
  struct IR
    def initialize(
      @tape : Array(Instr),
      @numbers : Array(Term::Num),
      @strings : Array(Term::Str),
      @labels : Array(Set(Label)),
      @jumptables : Array(JumpTable)
    )
    end

    # Returns the amount of instructions in this program.
    def size
      @tape.size
    end

    # Returns the *index*-th instruction without doing any safety checks.
    def at!(index : Int32)
      @tape.unsafe_fetch(index)
    end

    # Returns the constant at *addr* without doing any safety checks.
    def ldconst!(addr : Int32)
      {@numbers, @strings}
        .unsafe_fetch(addr >> 28)
        .unsafe_fetch(addr & 0x0fffffff)
    end

    # Returns the label set at *addr* without doing any safety checks.
    def labels!(addr : Int32)
      @labels.unsafe_fetch(addr)
    end

    # Fetches the jump table at *addr* without doing any safety checks,
    # asks the jump table to map *term* to an instruction pointer. On
    # success, this method returns the instruction pointer. Otherwise,
    # this method returns *f*.
    def brjt!(addr : Int32, term : Term, f : Int32)
      @jumptables.unsafe_fetch(addr)[term]? || f
    end

    # :nodoc:
    def stats
      {
        tape:       @tape.size,
        labels:     @labels.size,
        numbers:    @numbers.size,
        strings:    @strings.size,
        jumptables: @jumptables.size,
      }
    end

    private def to_s_lines(array, &)
      array.map_with_index do |item, index|
        "0x#{index.to_s(16, precision: 4)}| #{yield item}"
      end
    end

    def to_s(io)
      io << <<-END
        <LinearIR>
          <Constants>
            Numbers:
            #{to_s_lines(@numbers, &.itself).join("\n    ")}
            Strings:
            #{to_s_lines(@strings, &.itself).join("\n    ")}
            Labels:
            #{to_s_lines(@labels, &.itself).join("\n    ")}
          </Constants>
          <Jump tables>
            #{to_s_lines(@jumptables, &.itself).join("\n    ")}
          </Jump tables>
          <Tape>
          #{to_s_lines(@tape, &.itself).join("\n    ")}
          </Tape>
        </LinearIR>
      END
    end
  end

  # Sparse virtual machine. An *extremely* simple virtual machine that
  # explores what was before "a filter system", and now is a NFA-ish
  # jump madness.
  struct VM
    include Raktor

    @stack = [] of Term

    # Returns the sign bit of *n*.
    @[AlwaysInline]
    private def signbit(n : Float64)
      ((n.unsafe_as(UInt64) & 0x8000000000000000u64) >> 63).unsafe_as(Int32)
    end

    # Returns `1` if *n* is nonzero, `0` otherwise.
    @[AlwaysInline]
    private def nonzero?(n : Int32) : Int32
      ((n | (~n &+ 1)) >> 31) & 1
    end

    # Returns `1` if *n* is nonzero, `0` otherwise.
    @[AlwaysInline]
    private def nonzero?(n : Float64) : Int32
      n = n.unsafe_as(UInt64)
      (((n | (~n &+ 1)) >> 63) & 1).unsafe_as(Int32)
    end

    # Returns *t* if *bit* is `1`, *f* if *bit* is `0`.
    @[AlwaysInline]
    private def br(bit : Int32, t : Int32, f : Int32) : Int32
      f + (t - f) * bit
    end

    # Returns *t* if *a* and *b* are the same number, *f* if *a* and
    # *b* are different numbers.
    @[AlwaysInline]
    private def bre(a : Int32, b : Int32, t : Int32, f : Int32) : Int32
      br(nonzero?(a - b), f, t)
    end

    # Returns *t* if *a* is less than *b*, *f* otherwise.
    @[AlwaysInline]
    private def lt(a : Float64, b : Float64, t : Int32, f : Int32) : Int32
      br(signbit(a - b), t, f)
    end

    # Runs the given *ir* on *term*, adds facts about the term to
    # fact set *facts*.
    def run(ir, facts : FactSet, term : Term)
      @stack.clear

      a = b = term

      ip = 0

      while true
        instr = ir.at!(ip)

        case instr.opcode
        in .hlt?   then break
        in .pop?   then a = @stack.pop
        in .ldb?   then b = ir.ldconst!(instr.a0)
        in .j?     then next ip = instr.a0
        in .jt?    then next ip = ir.brjt!(instr.a0, a, ip + 1)
        in .numj?  then next ip = bre(a.typeid, Term::TypeID::NUM, instr.a0, ip + 1)
        in .strj?  then next ip = bre(a.typeid, Term::TypeID::STR, instr.a0, ip + 1)
        in .boolj? then next ip = bre(a.typeid, Term::TypeID::BOOL, instr.a0, ip + 1)
        in .dictj? then next ip = bre(a.typeid, Term::TypeID::DICT, instr.a0, ip + 1)
        in .divbyj?
          x = a.as(Term::Num).value
          y = b.as(Term::Num).value
          unless y == 0
            # If remainder is nonzero then X isn't divisible by Y.
            ip = br(nonzero?(x % y), ip + 1, instr.a0)
            next
          end
        in .ltj?
          # A < B = A - B < 0 => (A - B) sign bit = 1
          x = a.as(Term::Num).value
          y = b.as(Term::Num).value
          ip = lt(x, y, instr.a0, ip + 1)
          next
        in .gtj?
          # A > B = B < A
          x = a.as(Term::Num).value
          y = b.as(Term::Num).value
          ip = lt(y, x, instr.a0, ip + 1)
          next
        in .ltej?
          # A <= B = !(B < A)
          x = a.as(Term::Num).value
          y = b.as(Term::Num).value
          ip = lt(y, x, ip + 1, instr.a0)
          next
        in .gtej?
          # A >= B = !(A < B)
          x = a.as(Term::Num).value
          y = b.as(Term::Num).value
          ip = lt(x, y, ip + 1, instr.a0)
          next
        in .attrj?
          if value = a.as(Term::Dict)[b]?
            @stack << a
            a = value
            ip = instr.a0
            next
          end
        in .match?
          facts.append(ir.labels!(instr.a0))
        in .matchpopj?
          facts.append(ir.labels!(instr.a0))
          a = @stack.pop
          ip = instr.a1
          next
        in .matchlt?
          facts.append(ir.labels!(instr.a0))
          break
        end

        ip += 1
      end
    end
  end
end
