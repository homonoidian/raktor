require "./spec_helper"

def check(object)
  io = IO::Memory.new
  Cannon.encode(io, object)
  io.rewind
  Cannon.decode(io, Message).should eq(object)
end

def check_termir(term : Term)
  term.to_ir.to_term.should eq(term)
end

include Raktor
include Protocol

describe Raktor::Protocol do
  describe "serialization/deserialization of world" do
    it "should serialize RequestUniqueIdRange" do
      check(Message[Opcode::RequestUniqueIdRange])
    end

    it "should serialize register sensor" do
      check(Message[Opcode::RegisterSensor, 123u64, Term::Str.new("hello world")])
    end

    it "should serialize register appearance" do
      check(Message[Opcode::RegisterAppearance, 123u64])
    end

    it "should serialize set appearance" do
      check(Message[Opcode::SetAppearance, 123u64, Term::Num.new(100)])
      check(Message[Opcode::SetAppearance, 123u64, Term::Str.new("hello world")])
      check(Message[Opcode::SetAppearance, 123u64, Term::Bool.new(true)])
      check(Message[Opcode::SetAppearance, 123u64, Term::Dict[Term::Num.new(1), Term::Num.new(2), Term::Num.new(3)]])
    end
  end

  describe "serialization/deserialization of node" do
    it "should serialize AcceptUniqueIdRange" do
      check(Message[Opcode::AcceptUniqueIdRange, 0, 1024])
    end

    it "should serialize initsensor" do
      check(Message[Opcode::InitSensor, 123u64])
    end

    it "should serialize initappearance" do
      check(Message[Opcode::InitAppearance, 123u64])
    end

    it "should serialize sense" do
      check(Message[Opcode::Sense, 123u64, Term::Num.new(100)])
      check(Message[Opcode::Sense, 123u64, Term::Str.new("hello world")])
      check(Message[Opcode::Sense, 123u64, Term::Bool.new(true)])
      check(Message[Opcode::Sense, 123u64, Term::Dict[Term::Num.new(1), Term::Num.new(2), Term::Num.new(3)]])
    end
  end

  describe "convert term to termir" do
    it "should convert num to termir" do
      check_termir(Term::Num.new(0))
    end

    it "should convert str to termir" do
      check_termir(Term::Str.new("hello world"))
    end

    it "should convert bool to termir" do
      check_termir(Term::Bool.new(true))
      check_termir(Term::Bool.new(false))
    end

    it "should convert dict to termir" do
      check_termir(Term::Dict[Term::Num.new(1), Term::Num.new(2), Term::Num.new(3)])
      check_termir(Term::Dict[name: Term::Str.new("John Doe"), age: Term::Num.new(123)])
      lst = Term::Dict[Term::Dict[Term::Num.new(1), Term::Num.new(2), Term::Num.new(3)], Term::Dict[Term::Num.new(4), Term::Num.new(5), Term::Num.new(6)], Term::Dict[Term::Num.new(7), Term::Num.new(8), Term::Num.new(9)]]
      check_termir(lst)
      check_termir(Term::Dict[name: Term::Str.new("John Doe"), nested: lst, age: Term::Num.new(123)])
    end
  end
end
