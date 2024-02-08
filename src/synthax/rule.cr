module Sthx
  module Rule
    # Evaluates this rule within the given parser context *ctx*.
    abstract def eval(ctx : Ctx) : Ctx | Err

    # :nodoc:
    def eval(ctx : Ctx, & : Ctx -> Ctx | Err) : Ctx | Err
      result = eval(ctx)
      result.is_a?(Ctx) ? yield result : result
    end

    # Parses a single character from the specified character range.
    struct FromRange
      include Rule

      def initialize(@range : Range(Char, Char))
      end

      def eval(ctx : Ctx) : Ctx | Err
        ctx.char.in?(@range) ? ctx.advance : Err.new(ctx)
      end
    end

    # Forward declaration of a rule.
    class Ahead
      include Rule

      # Assigns *rule*, should be called when its definition becomes available.
      #
      # ```
      # expr = Rule.ahead
      # expr.put('(' & expr*(0..1) & ')')
      #
      # "(((())))".apply?(expr) # => Tree
      # "((())".apply?(expr)    # => nil
      # ```
      def put(@rule : Rule) : self
        self
      end

      def eval(ctx : Ctx) : Ctx | Err
        raise NotImplementedError.new("ahead: no matching put()") unless rule = @rule

        rule.eval(ctx)
      end
    end

    # Captures the result of a rule into a subtree with the specified id.
    class Capture
      include Rule

      def initialize(@rule : Rule, @id : String)
      end

      def eval(ctx : Ctx) : Ctx | Err
        @rule.eval(ctx.rebase(@id)) { |sub| ctx.adopt(sub) }
      end
    end

    # Captures the string matched by of a rule and saves it in the tree
    # under a mapping with the specified id.
    class Keep
      include Rule

      def initialize(@rule : Rule, @id : String)
      end

      def eval(ctx : Ctx) : Ctx | Err
        @rule.eval(ctx.rebase(@id)) do |sub|
          span = sub.progress - ctx.progress
          substring = String.build(span) do |io|
            span.times do
              io << ctx.char
              ctx.advance
            end
          end
          ctx.copy_with(root: ctx.root.setattr(@id, substring))
        end
      end
    end

    # A sequence of rules. If a preceding rule fails the consecutive ones
    # will not match.
    struct Chain
      include Rule

      def initialize(@rules : Array(Rule))
      end

      def &(other)
        Chain.new(@rules.dup.push(Rule.from(other)))
      end

      def eval(ctx : Ctx) : Ctx | Err
        @rules.reduce(ctx) do |ctx, rule|
          result = rule.eval(ctx)
          result.is_a?(Ctx) ? result : return result
        end
      end
    end

    # A choice of multiple rules. If one fails the next one is tried.
    struct Branch
      include Rule

      enum Mode
        Seq
        Tourney
      end

      def initialize(@rules : Array(Rule), @mode = Mode::Seq)
      end

      def |(other)
        Branch.new(@rules.dup.push(Rule.from(other)))
      end

      def eval(ctx : Ctx) : Ctx | Err
        winner = nil

        case @mode
        in .seq?
          # Sequential mode: try each branch in turn.
          @rules.each do |rule|
            result = rule.eval(ctx)
            return result unless result.is_a?(Err)
            next unless winner.nil? || winner.progress < result.progress
            winner = result
          end
        in .tourney?
          # Tourney mode: pick a Ctx with most progress out of all choices,
          # or Err with most progress if no Ctxs.
          @rules.each do |rule|
            result = rule.eval(ctx)
            next unless winner.nil? || winner.progress < result.progress
            next if winner.is_a?(Ctx) && result.is_a?(Err)
            winner = result
          end
        end

        winner.not_nil!
      end
    end

    # Refuse to match certain characters/rules.
    class Refuse
      include Rule

      def initialize(@body : Rule, @cond : Rule)
      end

      def eval(ctx : Ctx) : Ctx | Err
        if mctx = @cond.eval(ctx).as?(Ctx)
          return Err.new(mctx)
        end

        @body.eval(ctx)
      end
    end

    # Repeat a rule some number of times.
    class Repeat
      include Rule

      protected def initialize(@body : Rule, @range : Range(Int32, Int32?), @min : Int32)
      end

      def self.new(body : Rule, times)
        b = times.begin || 0
        e = times.end.as(Int32?)
        new(body, range: times.exclusive? ? 0...e : 0..e, min: b)
      end

      def eval(ctx : Ctx) : Ctx | Err
        @range.reduce(ctx) do |ctx, niter|
          result = @body.eval(ctx)
          result.is_a?(Ctx) ? result : return (niter >= @min ? ctx : result)
        end
      end
    end

    # Forward declares a rule.
    #
    # ```
    # expr = Rule.ahead
    # expr.put('(' & maybe(expr) & ')')
    # ```
    def self.ahead
      Ahead.new
    end

    # Creates a `Rule` from the given `Char` *object*.
    def self.from(object : Char)
      FromRange.new(object..object)
    end

    # Creates a `Rule` from the given character range *object*. Any character
    # that is in the range will match.
    def self.from(object : Range(Char, Char))
      FromRange.new(object)
    end

    # :ditto:
    def self.from(object : Range(Int, Int))
      from(Range.new(object.begin.chr, object.end.chr, object.exclusive?))
    end

    # Creates a `Rule` from the given `String` *object*.
    #
    # This works by joining the characters of the string in a chain (i.e. `"foo"`
    # is the same as `'f' & 'o' & 'o'`).
    def self.from(object : String)
      rules = Array(Rule).new(object.size)
      object.each_char do |char|
        rules << from(char)
      end
      Chain.new(rules)
    end

    # :nodoc:
    def self.from(object : Rule)
      object
    end

    # Captures *other* into a subtree with the given *id*.
    #
    # ```
    # foo = Rule.capture('a', "foo")
    # bar = Rule.capture('b', "bar")
    #
    # "a".apply?(foo | bar)
    # # =>
    # # <root> ⸢0-1⸥
    # #   foo ⸢0-1⸥
    #
    # "b".apply?(foo | bar)
    # # =>
    # # <root> ⸢0-1⸥
    # #   bar ⸢0-1⸥
    # ```
    def self.capture(other, id : String)
      Capture.new(from(other), id)
    end

    # Defines a tree attribute with the given *name* whose value is the underlying
    # string content of *other*.
    #
    # ```
    # a = Rule.capture("a", "foo")
    # b = Rule.capture("b", "bar")
    # quux = Rule.keep(a | b, "match")
    #
    # # Note how the "foo" and "bar" capture subtrees are thrown away!
    # "a".apply!(quux) # => root ⸢0-1⸥ match="a"
    # "b".apply!(quux) # => root ⸢0-1⸥ match="b"
    # ```
    def self.keep(other, name : String)
      Keep.new(from(other), name)
    end

    # Asserts that one of *rules* must match. If multiple rules match the winning
    # one (the one that made most progress, i.e. read more source code than others)
    # is picked.
    #
    # ```
    # x = Rule.capture("xxx", "x")
    # y = Rule.capture("xxxy", "y")
    # foo = Rule.tourney(x, y)
    #
    # "xxx".apply!(foo)
    # # => root ⸢0-3⸥
    # #    └─ x ⸢0-3⸥
    #
    # "xxxy".apply!(foo)
    # # => root ⸢0-4⸥
    # #    └─ y ⸢0-4⸥
    # ```
    def self.tourney(*rules : Rule)
      Branch.new([*rules] of Rule, mode: Branch::Mode::Tourney)
    end

    # Repeats `self` a number of *times*.
    #
    # - `..` means repeat zero or more times
    # - `n..` means repeat *n* or more times
    # - `..m`/`...m` means repeat zero to and including/excluding *m* times
    # - `n..m`/`n...m` means repeat *n* to and including/excluding *m* times
    #
    # Due to how (weirdly?) Crystal ranges are parsed you'll almost always
    # want the range in parentheses.
    #
    # ```
    # xs = Rule.from('x') * (1..)
    # "".apply?(xs)    # => nil
    # "x".apply?(xs)   # => Tree
    # "xx".apply?(xs)  # => Tree
    # "xxx".apply?(xs) # => Tree
    # # ...
    # ```
    def *(times : Range)
      Repeat.new(self, times)
    end

    # Asserts that *other* must follow `self` for a match to occur.
    #
    # ```
    # xy = Rule.from('x') & Rule.from('y')
    # "".apply?(xy)   # => nil
    # "x".apply?(xy)  # => nil
    # "xa".apply?(xy) # => nil
    # "xy".apply?(xy) # => Tree
    # "yx".apply?(xy) # => nil
    # ```
    def &(other)
      Chain.new([self, Rule.from(other)] of Rule)
    end

    # Asserts that either `self` or *other* must match for a match to occur,
    # in that order. This is most useful for simple alternatives. For more
    # ambiguous alternatives a tourney branch can be useful, see `tourney`.
    #
    # ```
    # xy = Rule.from('x') | Rule.from('y')
    # "".apply?(xy)  # => nil
    # "x".apply?(xy) # => Tree
    # "y".apply?(xy) # => Tree
    # "z".apply?(xy) # => nil
    # ```
    def |(other)
      Branch.new([self, Rule.from(other)] of Rule)
    end

    # Asserts that *other* must *not* match for `self` to match.
    #
    # ```
    # foo = Rule.from('a'..'z') - 'x'
    # "a".apply?(xy) # => Tree
    # "z".apply?(xy) # => Tree
    # "x".apply?(xy) # => nil
    # ```
    def -(other)
      Refuse.new(self, Rule.from(other))
    end

    # :nodoc:
    macro def_dsl
      # See `::Sthx::Rule#*`.
      def *(times : Range)
        ::Sthx::Rule.from(self) * times
      end

      # See `::Sthx::Rule#&`.
      def &(other)
        ::Sthx::Rule.from(self) & other
      end

      # See `::Sthx::Rule#|`.
      def |(other)
        ::Sthx::Rule.from(self) | other
      end
    end
  end
end
