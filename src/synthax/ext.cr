struct ::Char
  Sthx::Rule.def_dsl
end

struct ::Range(B, E)
  Sthx::Rule.def_dsl

  # See `Sthx::Rule#-`.
  def -(other)
    Sthx::Rule.from(self) - other
  end
end

class ::String
  Sthx::Rule.def_dsl

  # Parses this string using *rule*. Returns the resulting parse context
  # `Ctx` if parsing succeeded, or `Err` if parsing failed.
  #
  # All subtrees (captures) are rooted under a tree with the id given
  # by *origin*.
  #
  # - *rule* is the rule to parse.
  # - *offset* specifies the index of the character (as in `#[]`) where
  #   to begin matching *rule*.
  # - *exact* specifies whether the resulting match should encompass
  #   this string entirely.
  # - *origin* is the id that should be used for the root of the tree.
  #
  # ```
  # "foo".apply("foo") # => Ctx(reader : Char::Reader, tree : Tree)
  # "foo".apply("bar") # => Err(ctx : Ctx)
  # ```
  def apply(rule : Sthx::Rule, *, offset = 0, exact = false, origin = "root") : Sthx::Ctx | Sthx::Err
    ctx = Sthx::Ctx.new(root: Sthx::Tree.new(origin, offset), reader: Char::Reader.new(self, offset))
    rule.eval(ctx) do |ctx|
      exact && !ctx.at_end? ? Sthx::Err.new(ctx) : ctx.terminate
    end
  end

  # Converts *other* into a rule using `Sthx::Rule.from`, otherwise
  # the same as `apply`.
  def apply(other, **kwargs)
    apply(Sthx::Rule.from(other), **kwargs)
  end

  # Same as `apply` but returns the resulting parse tree, or `nil` if
  # parsing failed.
  #
  # ```
  # "foo".apply?("foo") # => Tree
  # "foo".apply?("bar") # => nil
  # ```
  def apply?(*args, **kwargs) : Sthx::Tree?
    case result = apply(*args, **kwargs)
    in Sthx::Err then nil
    in Sthx::Ctx then result.root
    end
  end

  # Same as `apply?` but raises `SyntaxError` instead of returning `nil`.
  #
  # ```
  # "foo".apply!("foo") # => Tree
  # "foo".apply!("bar") # => raises SyntaxError
  # ```
  def apply!(*args, **kwargs) : Sthx::Tree
    case result = apply(*args, **kwargs)
    in Sthx::Err then raise Sthx::SyntaxError.new(result)
    in Sthx::Ctx then result.root
    end
  end
end
