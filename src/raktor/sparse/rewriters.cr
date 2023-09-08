module Raktor::Sparse
  # Includers can rewrite a `RuleBook`.
  module BookRewriter
    # Mutably rewrites the given *book*, may publish label substitutions
    # to the given substitution table *subst*.
    abstract def rewrite(book, subst)
  end

  # Substitutes identical rules with a single rule. Labels of identical
  # rules will be substituted with a label pointing to the single rule.
  #
  # ```text
  # // ...
  # %1 = %2;
  # %2 = %2;
  # %3 = %2;
  # %4 = %1 | %2 | %3 | %4;
  #
  # ===> // + unused rule remover
  #
  # // ...
  # %5 = %2;
  # %4 = %5; // to be processed by binding rewriter
  # ```
  struct BookRewriter::SameBodyRewriter
    include BookRewriter

    @_groups = {} of Rule => Array(Label)

    def rewrite(book, subst)
      book.each_rule_with_label do |rule, label|
        instances = @_groups[rule] ||= [] of Label
        instances << label
      end

      @_groups.each do |rule, labels|
        next if labels.size < 2

        book.defrule do |common|
          # Remove rules in identicals (including head itself) from
          # the rule book.
          labels.each &.replace_with(common, in: subst)
          rule
        end
      end
    ensure
      @_groups.clear
    end
  end

  # Substitutes binding rules with what they are binding to.
  #
  # ```text
  # export 0 = %2;
  # // ...
  # %1 = %2;
  # %2 = %3;
  # %3 = %4;
  # %4 = %5 | %6;
  #
  # ===> // + unused rule remover
  #
  # export 0 = %4;
  # // ...
  # %4 = %5 | %6;
  # ```
  struct BookRewriter::BindingRewriter
    include BookRewriter

    def rewrite(book, subst)
      book.each_rule_with_label do |rule, label|
        next unless target = rule.binding?

        label.replace_with(target, in: subst)
      end
    end
  end

  # Embeds nested and/or rules.
  #
  # ```text
  # export 0 = %2;
  # // ...
  # %1 = %3 | %4;
  # %2 = %1 | %5;
  #
  # ===> // + unused rule remover
  #
  # export 0 = %2;
  # // ...
  # %2 = %3 | %4 | %5;
  # ```
  struct BookRewriter::AndOrEmbedder
    include BookRewriter

    def rewrite(book, subst)
      book.each_rule_with_label(Rule::Comb::And, Rule::Comb::Or) do |outer, label|
        outer.each_arg_embed do |arg|
          next arg unless inner = book.rule_for?(arg)
          next arg unless inner.comb == outer.comb

          # We can only embed and into and, or into or etc.

          inner
        end
      end
    end
  end

  # Embeds nested not rules.
  #
  # ```text
  # export 0 = %2;
  # // ...
  # %1 = not(%3);
  # %2 = not(%1);
  #
  # ===> // + unused rule remover
  #
  # export 0 = %2;
  # // ...
  # %2 = %3; // to be processed by binding rewriter
  # ```
  struct BookRewriter::NotEmbedder
    include BookRewriter

    def rewrite(book, subst)
      book.each_rule_with_label(Rule::Comb::Not) do |outer, label|
        next unless arg = outer.first_arg?
        next unless inner = book.rule_for?(arg)
        next unless inner.comb.not?
        next unless inner_arg = inner.first_arg?

        # So we've got a not(not(_)) situation, we need to
        # replace the outer not with whatever `_` is.
        label.replace_with(inner_arg, in: subst)
      end
    end
  end

  struct BookRewriter::OrToAndRewriter
    include BookRewriter

    def rewrite(book, subst)
      book.each_rule_with_label(Rule::Comb::Or) do |rule, label|
        nor = book.combine(rule, Rule::Comb::And) do |arg|
          book.defrule { Rule.new(Rule::Comb::Not, Set{arg}) }
        end

        book.update_rule_for(label, Rule.new(Rule::Comb::Not, Set{nor}))
      end
    end
  end

  # Removes unused rules. An unused rule is a rule whose label
  # is an untagged label that is not an argument in any rule.
  struct BookRewriter::UnusedRuleRemover
    include BookRewriter

    @_seen = Set(Label).new
    @_delete = [] of Label

    def rewrite(book, subst)
      # Tagged labels must always be kept because the outside
      # world is interested in them.
      book.each_tagset_with_label { |_, label| @_seen << label }

      # Go through the arguments of rules and see which labels
      # are used.
      book.each_rule_with_label do |rule, label|
        rule.each_arg { |arg| @_seen << arg }
      end

      # Go through the book once more, remember rules whose
      # labels were not used even once.
      book.each_rule_with_label do |_, label|
        next if label.in?(@_seen)

        @_delete << label
      end

      # Remove the unused rules we've remembered.
      @_delete.each do |label|
        book.delete_rule_for(label)
      end
    ensure
      @_seen.clear
      @_delete.clear
    end
  end
end
