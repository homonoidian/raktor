require "./src/raktor"
require "./isprime"

include Raktor
include Raktor::Protocol

host = MapServer.new

# What you see below is total nonsense Raktor-wise, no kernels, no mappers,
# no philosophy, nothing; what's below is just to prove that the thing could
# be put together in a way that "essentially" works.
#
# Without things like constraints, we can't do any proper recursion (aka
# feedback here in Raktor), and therefore can't find prime numbers
# "domestically" (yet!)

# { n < 2 }           not prime
# { n: 2 }            prime
# { n /? I, i: I }    not prime
# { n: N, i ^ 2 > N } prime
# ...?

# Counter reacts to itself in a feedback, increments a number.
counter = MapServer.new
counter.on_init do |mediator|
  mediator.senses(:start, %(number))
  mediator.appears_as(:counter)
end

counter.on_init_appearance do |mediator|
  mediator.set(:counter, Term::Num.new(0)) # Kickstart at zero
end

counter.on_sense do |term, mediator|
  count = term.as(Term::Num)
  mediator.set(:counter, count + Term::Num.new(1))
end

# Printer prints every prime number

prime_printer = MapServer.new
prime_printer.on_init do |mediator|
  mediator.senses(:prime_number, %({ prime: true, value: number }))
end

prime_printer.on_sense do |term, mediator|
  dict = term.as(Term::Dict)
  puts "Prime: #{dict.getattr?(Term::Str.new("value"))}"
end

# Isprime reacts to counter & filters only prime numbers

isprime = MapServer.new
isprime.on_init do |mediator|
  mediator.senses(:some_number, %(number))
  mediator.appears_as(:primeness_marked_number)
end

isprime.on_sense do |term, mediator|
  number = term.as(Term::Num)
  mediator.set(:primeness_marked_number, Term::Dict[prime: Term::Bool.new(number.value.prime?), value: number])
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
