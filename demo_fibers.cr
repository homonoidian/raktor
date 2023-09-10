require "./src/raktor"
require "./isprime"

include Raktor
include Raktor::Protocol

host = MapServer.new

# FIXME: this works but suffers from queue overflow. counter is too fast
#        for isprime. therefore the program breaks down after a while,
#        randomly. implementing backpressure should help
#
# TODO: ids should bot be provided by hand!!!

# Counter reacts to itself in a feedback, increments a number.

counter = MapServer.new
counter.on_init do |mediator|
  mediator.sense(0, %(number))
  mediator.appearance(1)
end

counter.on_init_appearance do |mediator|
  mediator.appear(1, Term::Num.new(0))
end

counter.on_sense do |term, mediator, sensor|
  next unless sensor == 0
  count = term.as(Term::Num)
  mediator.appear(1, count + Term::Num.new(1))
end

# Printer simply prints every prime number

prime_printer = MapServer.new
prime_printer.on_init do |mediator|
  mediator.sense(2048, %({ prime: true, value: number }))
end

prime_printer.on_sense do |term, mediator, sensor|
  next unless sensor == 2048
  dict = term.as(Term::Dict)
  puts "Prime: #{dict.getattr?(Term::Str.new("value"))}"
end

# Isprime reacts to counter & filters only prime numbers

isprime = MapServer.new
isprime.on_init do |mediator|
  mediator.sense(1024, %(number))
  mediator.appearance(1025)
end

isprime.on_sense do |term, mediator, sensor|
  next unless sensor == 1024
  number = term.as(Term::Num)
  mediator.appear(1025, Term::Dict[prime: Term::Bool.new(number.value.prime?), value: number])
end

router = NamedParcelEndpointRouter.new
router.assign(:host, host.spawn)
router.assign(:counter, counter.spawn)
router.assign(:prime_printer, prime_printer.spawn)
router.assign(:isprime, isprime.spawn)

# Simulate nodes "joining" the host

router.send(:prime_printer, :host, Message[Opcode::RequestUniqueIdRange])
router.send(:counter, :host, Message[Opcode::RequestUniqueIdRange])
router.send(:isprime, :host, Message[Opcode::RequestUniqueIdRange])

sleep
