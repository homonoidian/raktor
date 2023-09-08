module Raktor::Sparse
  # Gates let terms matching some condition flow through from owner
  # filter's input to its output. Gates are the "working parts" of filters,
  # i.e., the things that are doing the filtering. Imagine gates as holes
  # in a sieve, where the holes are the gates, and the sieve is the filter
  # that "owns" them.
  abstract struct Gate
    include Machine

    enum Overlap
      # Gates are mutually exclusive.
      None
      Magnitude
      Divisibility
      Attribute
    end

    # Returns the slot which this gate should occupy in `Chain`.
    def slot
      Chain::Slot::First
    end

    # Returns the overlap category of this gate. Gates of the same
    # overlap category may have overlaps in terms of what they let
    # through (i.e. they're not mutually exclusive). Gates whose
    # overlap category is `Overlap::None` are mutually exclusive.
    def overlap : Overlap
      Overlap::None
    end

    # Returns whether this gate's input is equal to its output, meaning
    # the only thing this gate does is it decides whether to let input
    # pass through. On the other hand, gates that are not passthrough
    # can also vary their output as they desire, with or without
    # side effects.
    def passthrough?
      true
    end

    # Creates and returns an instance of `Filter` which receives terms
    # from the given *filter* via this gate.
    def transfer(to filter : Filter) : Filter
      filter.connect(via: self, to: Filter.new)
    end

    # Emits verification bytecode to *target*.
    #
    # *ok* is jumped to if verification succeeds.
    #
    # *err* is jumped to if verification fails.
    abstract def compile(compiler, ok, err, to target)
  end

  # Base class of all typechecking gates.
  abstract struct Gate::Type < Gate
  end

  # Lets a term through only if it is a number.
  struct Gate::IsNum < Gate::Type
    def slot
      Chain::Slot::Typecheck
    end

    def compile(compiler, ok, err, to target)
      target.emit(VarInstr[Opcode::NUMJ, ok])
      target.emit(VarInstr[Opcode::J, err])
      target
    end
  end

  # Lets a term through only if it is a string.
  struct Gate::IsStr < Gate::Type
    def slot
      Chain::Slot::Typecheck
    end

    def compile(compiler, ok, err, to target)
      target.emit(VarInstr[Opcode::STRJ, ok])
      target.emit(VarInstr[Opcode::J, err])
      target
    end
  end

  # Lets a term through only if it is a boolean.
  struct Gate::IsBool < Gate::Type
    def slot
      Chain::Slot::Typecheck
    end

    def compile(compiler, ok, err, to target)
      target.emit(VarInstr[Opcode::BOOLJ, ok])
      target.emit(VarInstr[Opcode::J, err])
      target
    end
  end

  # Lets a term through only if it is a dictionary.
  struct Gate::IsDict < Gate::Type
    def slot
      Chain::Slot::Typecheck
    end

    def compile(compiler, ok, err, to target)
      target.emit(VarInstr[Opcode::DICTJ, ok])
      target.emit(VarInstr[Opcode::J, err])
      target
    end
  end

  # Base class of magnitude gates.
  abstract struct Gate::Magnitude < Gate
    def overlap
      Overlap::Magnitude
    end
  end

  # Lets a term through only if it is less than the provided number.
  # The term should have already been proven to be a number.
  struct Gate::Lt < Gate::Magnitude
    def initialize(@n : Float64)
    end

    def slot
      Chain::Slot::Magnitude
    end

    def compile(compiler, ok, err, to target)
      target.emit(VarInstr[Opcode::LDB, compiler.const(@n)])
      target.emit(VarInstr[Opcode::LTJ, ok])
      target.emit(VarInstr[Opcode::J, err])
      target
    end
  end

  # Lets a term through only if it is less than or equal to the provided
  # number. See `Gate::Lt` for general info.
  struct Gate::Lte < Gate::Magnitude
    def initialize(@n : Float64)
    end

    def slot
      Chain::Slot::Magnitude
    end

    def compile(compiler, ok, err, to target)
      target.emit(VarInstr[Opcode::LDB, compiler.const(@n)])
      target.emit(VarInstr[Opcode::LTEJ, ok])
      target.emit(VarInstr[Opcode::J, err])
      target
    end
  end

  # Lets a term through only if it is greater than the provided number.
  # See `Gate::Lt` for general info.
  struct Gate::Gt < Gate::Magnitude
    def initialize(@n : Float64)
    end

    def slot
      Chain::Slot::Magnitude
    end

    def compile(compiler, ok, err, to target)
      target.emit(VarInstr[Opcode::LDB, compiler.const(@n)])
      target.emit(VarInstr[Opcode::GTJ, ok])
      target.emit(VarInstr[Opcode::J, err])
      target
    end
  end

  # Lets a term through only if it is greater than or equal to the provided
  # number. See `Gate::Lt` for general info.
  struct Gate::Gte < Gate::Magnitude
    def initialize(@n : Float64)
    end

    def slot
      Chain::Slot::Magnitude
    end

    def compile(compiler, ok, err, to target)
      target.emit(VarInstr[Opcode::LDB, compiler.const(@n)])
      target.emit(VarInstr[Opcode::GTEJ, ok])
      target.emit(VarInstr[Opcode::J, err])
      target
    end
  end

  # Lets a term through only if it is divisible by the provided number.
  # The term should have already been proven to be a number.
  struct Gate::DivBy < Gate
    def initialize(@n : Float64)
    end

    def overlap
      Overlap::Divisibility
    end

    def slot
      Chain::Slot::Property
    end

    def compile(compiler, ok, err, to target)
      target.emit(VarInstr[Opcode::LDB, compiler.const(@n)])
      target.emit(VarInstr[Opcode::DIVBYJ, ok])
      target.emit(VarInstr[Opcode::J, err])
      target
    end
  end

  # Lets the value of a term's attribute through. The term should have
  # already been proven to be a dictionary.
  struct Gate::Attr < Gate
    def initialize(@attr : Term::Dict::Key)
    end

    def overlap
      Overlap::Attribute
    end

    def passthrough?
      false
    end

    def slot
      Chain::Slot::Fetch
    end

    def compile(compiler, ok, err, to target)
      target.emit(VarInstr[Opcode::LDB, compiler.const(@attr)])
      target.emit(VarInstr[Opcode::ATTRJ, ok])
      target.emit(VarInstr[Opcode::J, err])
      target
    end
  end

  # Lets a term through only if it exactly matches the provided term.
  struct Gate::Exact < Gate
    def initialize(@term : Term)
    end

    def slot
      Chain::Slot::Exact
    end

    def compile(compiler, ok, err, to target)
      target.map(@term, ok)
      target.emit(VarInstr[Opcode::J, err])
      target
    end
  end
end
