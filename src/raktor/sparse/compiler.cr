module Raktor::Sparse
  # An instruction with a variable number of arguments. Used during
  # compilation, later transformed into the fixed-arg `Machine::Instr`.
  struct VarInstr
    # Returns the opcode of this instruction.
    getter opcode

    # Returns the list of arguments to this instruction.
    getter args

    protected def initialize(@opcode : Machine::Opcode, @args : Array(Int32 | Chunk))
    end

    # Returns an instance of `VarInstr` with the given *opcode* and *args*.
    def self.[](opcode : Machine::Opcode, *args, **kwargs)
      arglist = args.each_with_object(Array(Int32 | Chunk).new(args.size)) do |arg, arglist|
        arg.apply(opcode) if arg.is_a?(Chunk)
        arglist << arg
      end
      new(opcode, arglist, **kwargs)
    end

    # Converts this instruction into a fixed-arg `Machine::Instr`.
    #
    # *tr* must be provided to transform chunk references in arguments
    # to instruction offsets.
    def to_machine_instr(tr : Hash(Chunk, Int32)) : Machine::Instr
      if args.size > 2
        raise ArgumentError.new("cannot convert >2 arg var instr into <=2 arg machine instr")
      end

      a0 = args[0]?
      a1 = args[1]?
      a0 = a0.is_a?(Chunk) ? tr[a0] : (a0 || 0)
      a1 = a1.is_a?(Chunk) ? tr[a1] : (a1 || 0)

      Machine::Instr.new(opcode, a0, a1)
    end

    def to_s(io)
      io << @opcode << " "

      @args.join(io, " ") do |arg|
        case arg
        in Int32
          io << "0x" << arg.to_s(16, precision: 4)
        in Chunk
          io << "0x" << arg.object_id.to_s(16)
        end
      end
    end
  end

  class Compiler
    include Machine

    def initialize(@filter : Filter)
      @chunks = [] of Chunk
      @numbers = {} of Float64 => Int32
      @terms = {} of Term => Int32
      @labels = {} of Set(Label) => Int32
      @jumptables = {} of Mapping(Term, Chunk) => Int32
    end

    # Emits and returns a new, empty chunk.
    def chunk : Chunk
      Chunk.new.tap { |chunk| @chunks << chunk }
    end

    # Returns constant address for *operand*, adding *operand* to the
    # appropriate constant pool if it is not there already.
    def const(operand : Float64)
      const(Term::Num.new(operand))
    end

    # :ditto:
    def const(operand : String)
      const(Term::Str.new(operand))
    end

    # :ditto:
    def const(operand : Term)
      @terms[operand] ||= @terms.size
    end

    # :ditto:
    def const(operand : Set(Label))
      @labels[operand] ||= @labels.size
    end

    # :ditto:
    def const(operand : Mapping(Term, Chunk))
      @jumptables[operand] ||= @jumptables.size
    end

    # Compiles the filter passed in the constructor into `IR`,
    # which is subsequently returned.
    def compile : IR
      # Note that the automata constructed by filter compilation are
      # branching but acyclic, because filter systems are acyclic (or,
      # rather, feedback is impossible to synthesize [I hope?!]).
      entry = @filter.compile(self, chunk, entry: true)

      # Explore all chunks starting from entry, form a "world" of them.
      world = {} of Chunk => Array(VarInstr)

      entry.defjt(self)

      keys = @jumptables.keys

      entry.populate(world, keys)

      comp = Panama(VarInstr, Opcode).new(&.opcode)

      # MATCH POP J -> MATCHPOPJ
      comp.on(Opcode::MATCH, Opcode::POP, Opcode::J) do |(match, _, j)|
        VarInstr[Opcode::MATCHPOPJ, match.args[0], j.args[0]]
      end

      # MATCH POP HLT -> MATCHLT
      comp.on(Opcode::MATCH, Opcode::POP, Opcode::HLT) do |(match, _)|
        VarInstr[Opcode::MATCHLT, match.args[0]]
      end

      # MATCH HLT -> MATCHLT
      comp.on(Opcode::MATCH, Opcode::HLT) do |(match, _)|
        VarInstr[Opcode::MATCHLT, match.args[0]]
      end

      # JT JT* -> JT [common]
      comp.on(Opcode::JT, Panama::Many[Opcode::JT]) do |instrs|
        if instrs.size > 1
          common = instrs.reduce(Mapping::Empty(Term, Chunk).new) do |mapping, instr|
            mapping.merge!(keys[instr.args[0].as(Int32)])
          end
          keys << common
          VarInstr[Opcode::JT, const(common)]
        else
          instrs[0]
        end
      end

      seen = {} of Mapping(Term, Chunk) => Int32
      index = 0
      offsets = {} of Chunk => Int32

      world.each do |chunk, batch|
        world[chunk] = batch = comp.compress(batch)
        batch.map! do |instruction|
          next instruction unless instruction.opcode.jt?
          next instruction unless address = instruction.args[0].as?(Int32)
          VarInstr[Opcode::JT, seen[keys[address]] ||= seen.size]
        end
        offsets[chunk] = index
        index += batch.size
      end

      @jumptables = seen

      # Create a new tape where instructions are fixed-argument machine
      # instructions, because up to this point we were using variable-
      # argument instructions.
      tape = [] of Instr
      world.each_value do |batch|
        batch.each { |instruction| tape << instruction.to_machine_instr(offsets) }
      end

      # Convert term -> chunk reference jumptables to term -> IP references.
      jumptables = @jumptables.each_with_object([] of Mapping(Term, Int32)) do |(jumptable, addr), result|
        result << jumptable.mapv { |ref| offsets[ref] }
      end

      IR.new(tape, @terms.keys, @labels.keys, jumptables)
    end

    # Shorthand for `Compiler.new(filter).compile`.
    def self.compile(filter : Filter) : IR
      new(filter).compile
    end
  end
end
