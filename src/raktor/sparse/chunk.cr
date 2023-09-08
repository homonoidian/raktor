module Raktor::Sparse
  alias JumpTable = Mapping(Term, Int32)

  # An array of instructions coupled with a jumptable. Chunks can
  # be referenced in instructions (e.g. jumped to), specifically
  # in `VarInstr` instructions.
  class Chunk
    @jumptable : Mapping(Term, Chunk)

    def initialize
      @jumptable = Mapping::Empty(Term, Chunk).new
      @instructions = [] of VarInstr
    end

    @jrefs = 0
    @irefs = 0

    # Returns the amount of instructions in this chunk.
    def size
      @instructions.size
    end

    def inlinable?
      @irefs.zero? && size <= 2
    end

    # Appends *instruction* to this chunk.
    def emit(instruction : VarInstr)
      # A sneaky one: if instructions
      @instructions << instruction
    end

    def <<(instruction : VarInstr)
      emit(instruction)
    end

    # Triggered by use within an instruction with the given *opcode*.
    def apply(opcode : Machine::Opcode)
      case opcode
      when .j?
        @jrefs += 1
      else
        @irefs += 1
      end
    end

    def undo(opcode : Machine::Opcode)
      case opcode
      when .j?
        @jrefs -= 1
      else
        @irefs -= 1
      end
    end

    # Returns whether this chunk ends with an instruction with the
    # given *opcode*.
    def ends_with?(opcode : Machine::Opcode) : Bool
      !!(last = @instructions.last?) && last.opcode == opcode
    end

    # Creates a mapping between *term* and a chunk *ref* in this
    # chunk's jumptable.
    def map(term : Term, ref : Chunk)
      ref.apply(Machine::Opcode::JT)

      @jumptable = @jumptable.put(term, ref)
    end

    @constjt : Int32? = nil

    def each_instruction(& : VarInstr ->)
      unless @jumptable.empty?
        raise "BUG: did you forget to call defjt?" unless constjt = @constjt
        yield VarInstr[Machine::Opcode::JT, constjt]
      end

      @instructions.each do |instr|
        yield instr
      end

      unless ends_with?(Machine::Opcode::J)
        yield VarInstr[Machine::Opcode::HLT]
      end
    end

    def defjt!(compiler)
      @constjt = compiler.const(@jumptable) unless @jumptable.empty?
    end

    def defjt(compiler)
      queue = [self]
      while chunk = queue.shift?
        chunk.defjt!(compiler)
        chunk.each_instruction do |instr|
          next if instr.opcode.jt?
          instr.args.each do |arg|
            next unless arg.is_a?(Chunk)
            queue << arg
          end
        end
      end
    end

    def populate(world, jumptables)
      queue = [self]

      while chunk = queue.shift?
        next if world.has_key?(chunk)

        index = 0
        batch = [] of VarInstr
        subbatch = [] of VarInstr

        chunk.each_instruction { |instr| batch << instr }

        while index < batch.size
          instr = batch.unsafe_fetch(index)

          case instr.opcode
          when .j?
            # Queue jumped-to chunk, or inline it into batch if it is inlinable.
            target = instr.args[0].as(Chunk)
            if target.inlinable?
              target.undo(Machine::Opcode::J)
              subbatch.clear
              target.each_instruction do |sub|
                subbatch << sub
              end
              batch[index..index] = subbatch
              next
            else
              queue << target
            end
          when .jt?
            # Queue chunks referenced in the jumptable.
            jumptables[instr.args[0].as(Int32)].each do |_, target|
              queue << target
            end
          else
            # Queue chunks from instruction arguments.
            instr.args.each do |arg|
              next unless arg.is_a?(Chunk)
              queue << arg
            end
          end

          index += 1
        end

        world[chunk] = batch
      end
    end

    def to_s(io)
      io << "(0x" << object_id.to_s(16) << "):"
      return if @instructions.empty?
      io << "\n"
      @instructions.each_with_index do |instruction, index|
        io << "0x" << index.to_s(16, precision: 4) << "| " << instruction << "\n"
      end
    end
  end

  def_equals_and_hash object_id
end
