module Raktor::Sparse
  # Represents a rule in a `RuleBook`.
  #
  # Rules combine one or more `Label`s using one of the available rule
  # combinators (see `Comb`).
  class Rule
    # Lists all possible rule combinators.
    enum Comb : UInt8
      # Bind combinator, as in rule `%0 = %1`.
      Bind

      # Conjunction combinator, as in rule `%0 = %1 & %2 & %3`.
      And

      # Disjunction combinator, as in rule `%0 = %1 | %2 | %3`
      Or

      # Negation (inversion) combinator, as in rule `%0 = not(%1)`.
      Not
    end

    # Returns the combinator used by this rule.
    getter comb

    def initialize(@comb : Comb, @args : Set(Label))
    end

    private def xchg_args(reuse : Set(Label), & : Label -> Label) : Set(Label)
      @args.each { |arg| reuse << (yield arg) }
      @args, prev = reuse, @args
      prev.clear
    end

    # Yields each argument of this rule in no particular order.
    def each_arg(& : Label ->)
      @args.each { |arg| yield arg }
    end

    # Yields each argument of this rule, ordering them by their score
    # in the given *scoreboard*, descending. Expects all arguments to
    # be in the scoreboard (alternatively, the hash may have a default
    # score).
    #
    # If *reuse* is given, that array is reused. This method clears
    # it automatically.
    def each_arg_by(scoreboard : Hash(Label, Int32), reuse = [] of {Int32, Label}, & : Label ->)
      reuse.clear

      @args.each do |pivot|
        score = scoreboard[pivot]
        index = reuse.bsearch_index { |(other, _)| other < score } || reuse.size
        reuse.insert(index, {score, pivot})
      end

      reuse.each { |(_, item)| yield item }
    end

    # Yields the arguments of this rule in no particular order.
    def each_arg_embed(& : Label -> Label | Rule) : self
      memo = Set(Label).new

      each_arg do |arg|
        (yield arg).transfer(memo)
      end

      @args = memo

      self
    end

    # Returns the first argument of this rule, if any.
    def first_arg? : Label?
      each_arg { |arg| return arg }
    end

    # Returns the number of arguments of this rule.
    def argcount : Int32
      @args.size
    end

    # Returns whether *arg* is an argument of this rule.
    def has_arg?(arg : Label)
      arg.in?(@args)
    end

    # Returns the label this rule binds to, if this rule is a binding
    # regardless of the combinator (for instance a single-argument rule
    # with combinator `Comb::And` is effectively a binding). If this
    # rule is not a binding, returns nil.
    def binding? : Label?
      return if @comb.not?
      return unless argcount == 1

      @args.first
    end

    # Applies substitution table *subst* to this rule's arguments.
    #
    # If *reuse* is given, reuses that set for the substituted arguments,
    # otherwise a new set is created. Returns the *cleared* old argument
    # set so that it can be reused.
    def apply(subst, reuse = Set(Label).new) : Set(Label)
      xchg_args(reuse, &.apply(subst))
    end

    # Normalizes this rule's arguments, obtaining new labels by
    # calling the given *getlabel* proc.
    def norm(getlabel, reuse = Set(Label).new) : Set(Label)
      xchg_args(reuse, &.norm(getlabel))
    end

    def transfer(args : Set(Label))
      args.concat(@args)
    end

    def to_s(io)
      case comb
      in .bind?
        @args.join(io, " = ")
      in .and?
        @args.join(io, " & ")
      in .or?
        @args.join(io, " | ")
      in .not?
        io << "not(" << @args.join(", ") << ")"
      end
    end

    # Two rules are equal when their combinators and arguments are
    # equal. Note that the order of arguments *does not* matter.
    def_equals_and_hash @comb, @args
  end

  # Rule buckets hold and manage associations between `Rule`s and `Label`s.
  # Importantly, rule buckets contain only rules with the same `Rule::Comb`.
  class Rule::Bucket
    def initialize
      @storage = {} of Label => Rule
    end

    # Yields each rule in this bucket, together with the label it is
    # associated with.
    def each_rule_with_label(& : Rule, Label ->)
      @storage.each { |label, rule| yield rule, label }
    end

    # Returns the rule associated with the given *label*.
    def rule_for?(label : Label)
      @storage[label]?
    end

    # Updates (creating if necessary) the association between *label*
    # and *rule*. Old associations of *label* are cleared.
    def update_rule_for(label : Label, rule : Rule)
      @storage[label] = rule
    end

    # Attempts to remove the rule associated with the given *label*.
    # Returns whether the rule was present and was successfully removed.
    def delete_rule_for(label : Label) : Bool
      !!@storage.delete(label)
    end

    @_transfer_aux = Set(Label).new

    # Merges the storage of this bucket with *storage*. Ids for labels
    # are obtained by calling *getlabel* with the current label id.
    def transfer(storage : Hash(Label, Rule), getlabel) : self
      @storage.each do |label, rule|
        @_transfer_aux = rule.norm(getlabel, reuse: @_transfer_aux)

        storage[label.norm(getlabel)] = rule
      end

      self
    end

    # Resets this rule bucket to its initial state. Clears the underlying
    # storage (wipes out all rules this bucket stores). Rules themselves
    # are kept intact.
    def clear
      @storage.clear
    end

    # Mutably merges this and *other* rule buckets. This bucket is mutated.
    # Ids for labels are obtained by calling *getlabel* with the current
    # label id.
    def merge!(other : Bucket, getlabel) : self
      other.transfer(@storage, getlabel)

      self
    end
  end

  # Rule stores create and manage buckets for each available rule
  # combinator, making it possible to iterate over rules of a specific
  # combinator without having to iterate over all the rules.
  struct Rule::Store
    def initialize
      @buckets = Array(Bucket).new({{ Comb.constants.size }}) { Bucket.new }
    end

    # Yields each rule in this store, together with the label it is
    # associated with.
    def each_rule_with_label(& : Rule, Label ->)
      @buckets.each do |bucket|
        bucket.each_rule_with_label { |rule, label| yield rule, label }
      end
    end

    # Same as `each_rule_with_label`, but yields only rules whose
    # combinator is any of the given *combinators*.
    def each_rule_with_label(*combinators : Comb, & : Rule, Label ->)
      combinators.each do |combinator|
        bucket = @buckets[combinator.value]
        bucket.each_rule_with_label do |rule, label|
          yield rule, label
        end
      end
    end

    # Returns the rule associated with the given *label*.
    def rule_for?(label : Label)
      @buckets.each do |bucket|
        next unless rule = bucket.rule_for?(label)
        return rule
      end
    end

    # Updates (creating if necessary) the association between *label*
    # and *rule*. Old associations of *label* are cleared.
    def update_rule_for(label : Label, rule : Rule)
      bucket = @buckets[rule.comb.value]
      bucket.update_rule_for(label, rule)

      @buckets.each do |other|
        next if bucket.same?(other)
        next unless other.delete_rule_for(label)
        break
      end
    end

    # Removes the rule associated with the given *label*.
    def delete_rule_for(label : Label)
      @buckets.each do |bucket|
        next unless bucket.delete_rule_for(label)
        return
      end
    end

    # Resets this rule store to its initial state; in turn clears
    # subordinate rule buckets.
    def clear
      @buckets.each &.clear
    end

    # Mutably merges this and *other* rule stores. This store is mutated.
    # Ids for labels are obtained by calling *getlabel* with the current
    # label id.
    def merge!(other : Rule::Store, getlabel)
      @buckets.zip(other.@buckets) { |dst, src| dst.merge!(src, getlabel) }
    end
  end
end
