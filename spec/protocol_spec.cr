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
include Terms
include Protocol

describe Raktor::Protocol do
  describe "serialization/deserialization of server" do
    it "should serialize register sensor" do
      check(Message[Opcode::RegisterFilter, 123u64, Str["hello world"]])
    end

    it "should serialize register appearance" do
      check(Message[Opcode::RegisterAppearance, 123u64])
    end

    it "should serialize set appearance" do
      check(Message[Opcode::SetAppearance, 123u64, Num[100]])
      check(Message[Opcode::SetAppearance, 123u64, Str["hello world"]])
      check(Message[Opcode::SetAppearance, 123u64, Boolean[true]])
      check(Message[Opcode::SetAppearance, 123u64, Dict[Num[1], Num[2], Num[3]]])
    end
  end

  describe "serialization/deserialization of client" do
    it "should serialize initsensor" do
      check(Message[Opcode::InitFilter, 123u64])
    end

    it "should serialize initappearance" do
      check(Message[Opcode::InitAppearance, 123u64])
    end

    it "should serialize sense" do
      check(Message[Opcode::Sense, 123u64, Num[100]])
      check(Message[Opcode::Sense, 123u64, Str["hello world"]])
      check(Message[Opcode::Sense, 123u64, Boolean[true]])
      check(Message[Opcode::Sense, 123u64, Dict[Num[1], Num[2], Num[3]]])
    end
  end

  describe "convert term to termir" do
    it "should convert num to termir" do
      check_termir(Num[0])
    end

    it "should convert str to termir" do
      check_termir(Str["hello world"])
    end

    it "should convert bool to termir" do
      check_termir(Boolean[true])
      check_termir(Boolean[false])
    end

    it "should convert dict to termir" do
      check_termir(Dict[Num[1], Num[2], Num[3]])
      check_termir(Dict[name: Str["John Doe"], age: Num[123]])
      lst = Dict[Dict[Num[1], Num[2], Num[3]], Dict[Num[4], Num[5], Num[6]], Dict[Num[7], Num[8], Num[9]]]
      check_termir(lst)
      check_termir(Dict[name: Str["John Doe"], nested: lst, age: Num[123]])
    end
  end
end
