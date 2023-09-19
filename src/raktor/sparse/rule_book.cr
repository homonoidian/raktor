module Raktor::Sparse
  # Central in rule books are *rules*, *labels* and *tags*.
  #
  # Labels are sort of like facts or observations. Rule book goes hand-
  # in-hand with a system of `Filter`s. Labels (in the form of filter
  # equations or simply *equations*) allow one to "tap into" filters
  # of interest.
  #
  # *Rules* combine more primitive observations (perhaps concrete filter
  # observations, e.g. "this is a number" and "it is divisible by 5") into
  # observations of higher abstraction ("this is a number divisible by 5")
  # using any of `Rule::Comb`inators.
  #
  # Finally, assigning *tags* to certain labels allows you to state your
  # (the outside world's relative to a rule book) interest in them, so
  # that they aren't thrown out during rewriting. It may happen that after
  # rewriting, the same tag will not correspond to the same label anymore,
  # but semantic unity is retained (the old and new labels unified).
  class RuleBook(Tag)
    def initialize
      @label = 0
      @rules = Rule::Store.new
      @tagsets = TransformableHash(Label, Set(Tag)).new
      @equations = Set(LabelSet).new
    end

    # See the same method in `Rule::Store`.
    delegate :rule_for?, :each_rule_with_label, :update_rule_for, :delete_rule_for, to: @rules

    # Returns the tagset for the given *label* (the set of outside-world,
    # i.e., `export`ed, tags associated with *label*).
    def tagset_for?(label : Label)
      @tagsets[label]?
    end

    # Yields each rule of this rule book.
    def each_rule(& : Rule ->)
      each_rule_with_label { |rule, _| yield rule }
    end

    # Yields each tag set of this rule book, accompanied by the label
    # to which the tags apply.
    def each_tagset_with_label(& : Set(Tag) ->)
      @tagsets.each { |label, tagset| yield tagset, label }
    end

    # Resets this rule book to its initial state, allowing you to reuse
    # `self` and avoid allocating/straining the GC.
    def clear
      @label = 0
      @rules.clear
      @tagsets.clear
      @equations.clear
    end

    # Adds *equation* to the list of equations in this rule book.
    def defequation(equation : LabelSet) : self
      @equations << equation

      self
    end

    # Swaps this book's list of equations with that which the given
    # *filter* defines (see `Filter#defequations`). The old list of
    # equations is cleared.
    def swap_equations(filter : Filter) : self
      @equations.clear

      filter.defequations(self)

      self
    end

    # Instead of allocating sets for all rules per each apply, we allocate
    # only *one* set, then ask the first rule to use it as its argument set,
    # and in exchange give us its old arguments set, which we pass to the
    # second rule and so on. After the last rule writes its old set here,
    # we basically don't need to do any Set allocations ever again.
    @_apply_aux = Set(Label).new

    # Applies the given substitution table *subst* to this rule book
    # (to all rules in this rule book etc.)
    def apply(subst : Subst) : self
      each_rule do |rule|
        @_apply_aux = rule.apply(subst, @_apply_aux)
      end

      @tagsets.transform! do |k1, v1, memo|
        next {k1, v1} unless k2 = subst.for?(k1)
        next {k2, v1} unless v2 = memo[k2]?

        # If the label we're rewriting to already had some tags attached
        # to it, then just reuse its set by appending our tags to its tags.
        {k2, v2.concat(v1)}
      end

      self
    end

    # Rewrites this rule book using *rewriters*.
    def rewrite(*rewriters : BookRewriter)
      rewrite(rewriters)
    end

    # Rewrites this rule book using *rewriters*.
    #
    # *unify* specifies whether the equations in this rule book should
    # be unified. There is no point in repeated unification of equations,
    # assuming the filter system those equations belong to hadn't changed
    # in the meantime (e.g. due to collation).
    def rewrite(rewriters : Enumerable(BookRewriter)? = nil, unify = true)
      if unify
        subst = Subst.new
        @equations.each &.unify(self, into: subst)
        subst.pop(self)
      end

      return unless rewriters && !rewriters.empty?

      subst ||= Subst.new

      while true
        changed = false
        rewriters.each do |rewriter|
          book_changed = rewriter.rewrite(self, subst)
          if subst.pop(self) || book_changed
            changed = true
          end
        end
        break unless changed
      end
    end

    # Emits and returns a new label.
    def newlabel : Label
      Label.new(@label.tap { @label += 1 })
    end

    # Yields a new label, expects the block to return a `Rule` whose result
    # you will then be able to refer to with the label. Returns the label.
    def defrule(& : Label -> Rule) : Label
      update_rule_for(label = newlabel, yield label)

      label
    end

    # Builds and adds a rule to this rule book; *comb* is set as the rule's
    # combinator, and its arguments are obtained by taking the return value
    # of the block for each *operand*. Additionally, the rule's result
    # label is provided to the block. Returns the rule's result label.
    def combine(operands : Enumerable(T), comb : Rule::Comb, & : T, Label -> Label) : Label forall T
      args = Set(Label).new(operands.size)

      defrule do |label|
        operands.each do |operand|
          args << (yield operand, label)
        end

        Rule.new(comb, args)
      end
    end

    # Builds and adds a rule to this rule book; *comb* is set as the rule's
    # combinator and *args* as its arguments. Returns the rule's result label.
    def combine(args : Enumerable(Label), comb : Rule::Comb) : Label
      combine(args, comb, &.itself)
    end

    # Builds and adds a rule to this rule book; *comb* is set as the rule's
    # combinator, and its arguments are obtained by taking the return value
    # of the block for each argument of the given *rule*. Returns the rule's
    # result label.
    def combine(rule : Rule, comb : Rule::Comb, & : Label -> Label) : Label
      args = Set(Label).new(rule.argcount)

      rule.each_arg do |arg|
        args << yield arg
      end

      defrule { Rule.new(comb, args) }
    end

    # Creates a tag set for *label* if one does not exist already,
    # adds *tag* to it.
    #
    # Tags exist to make certain labels "public", that is, to declare that
    # "the outside world" is interested in them so that they e.g. aren't
    # optimized away.
    def tag(label : Label, tag : Tag) : self
      tagset = @tagsets[label] ||= Set(Tag).new
      tagset << tag

      self
    end

    # Removes the given *tag* from this rule book, and cleans up this
    # rule book appropriately (including rewriting, so you don't need
    # to `rewrite` after you `untag`).
    def untag(tag : Tag)
      candidates = Set(Label).new

      # If a tagset contains the tag that we want to remove, and after
      # removing it from the tagset it becomes empty, then we should
      # search equations that mention the label associated with the now-
      # empty tagset, and also ask them to remove it. As for the rules
      # that use the label, we'll rewrite the book later; doing this
      # would result in "smarter" clean up.

      @tagsets.reject! do |label, tagset|
        if removed = tagset.delete(tag) && tagset.empty?
          candidates << label
        end
        removed
      end

      return if candidates.empty?

      @equations.reject! &.reject?(candidates)

      rewrite(
        {BookRewriter::SameBodyRewriter.new,
         BookRewriter::BindingRewriter.new,
         BookRewriter::UnusedRuleRemover.new},
        unify: false
      )

      # Cleanup equations: remove dead labels from them and if the
      # equation is empty afterward, reject it.
      seen = Set(Label).new

      each_tagset_with_label do |_, label|
        seen << label
      end

      each_rule_with_label do |rule, label|
        seen << label
        rule.each_arg do |arg|
          seen << arg
        end
      end

      @equations.reject! &.select?(seen)
    end

    # Mutably collates this and *other* rule books, this book is mutated.
    # Somewhat similar to `Filter#collate`.
    def collate(other : RuleBook(Tag))
      tr = {} of Label => Label # translation map

      other.transfer(@rules, @tagsets, ->(label : Label) { tr[label] ||= newlabel })
    end

    # Adds this book's rules to *rules*, this book's tagsets to *tagsets*;
    # obtains ids for labels that were encountered by calling the given
    # *getlabel* proc.
    def transfer(rules : Rule::Store, tagsets : TransformableHash(Label, Set(Tag)), getlabel)
      rules.merge!(@rules, getlabel)
      @tagsets.each do |label, tagset|
        tagsets[label.norm(getlabel)] = tagset
      end
      @equations.each &.norm(getlabel)
    end

    def to_s(io)
      @tagsets.each do |label, tagset|
        io << "export " << tagset.join(", ") << " = " << label << ";\n"
      end
      unless @equations.empty?
        io << "declare "
        @equations.join(io, ", ") do |equation|
          if equation.size == 1
            io << equation
          else
            io << "(" << equation.join(", ") << ")"
          end
        end
        io << ";\n"
      end
      @rules.each_rule_with_label do |rule, label|
        io << label << " = " << rule << ";\n"
      end
    end
  end
end
