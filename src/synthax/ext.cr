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

  # Parses this string using *rule*. Returns the parse context `Ctx` that made
  # most progress if one is available, or similarly the furthest `Err`.
  #
  # All subtrees (captures) are rooted under a tree with the id given by *root*.
  #
  # - *rule* is the rule to apply.
  # - *offset* specifies the index of the character (as in `#[]`) in this string
  #   where to begin applying *rule*.
  # - *exact* specifies whether *rule* should be expected to consume this string
  #   entirely; this not being so is treated as an error.
  # - *root* is the id that should be used for the root of the capture tree.
  #
  # ```
  # "foo".apply("foo") # => Ctx(..., tree : Sthx::Tree)
  # "foo".apply("bar") # => Err(ctx : Ctx)
  # ```
  def apply(rule : Sthx::Rule, *, offset = 0, exact = false, root = "root") : Sthx::Ctx | Sthx::Err
    ctx = Sthx::Ctx.new(root: Sthx::Tree.new(root, offset), reader: Char::Reader.new(self, offset))
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
  # "foo".apply?("foo", root: "program") # => program ⸢0-3⸥
  # "foo".apply?("bar", root: "program") # => nil
  # ```
  def apply?(*args, **kwargs) : Sthx::Tree?
    case result = apply(*args, **kwargs)
    in Sthx::Err then nil
    in Sthx::Ctx then result.root
    end
  end

  # Same as `apply?` but raises `Sthx::SyntaxError` instead of returning `nil`
  # if parsing failed.
  #
  # ```
  # "foo".apply!("foo", root: "program") # => program ⸢0-3⸥
  # "foo".apply!("bar", root: "program") # => raises Sthx::SyntaxError
  # ```
  def apply!(*args, **kwargs) : Sthx::Tree
    case result = apply(*args, **kwargs)
    in Sthx::Err then raise Sthx::SyntaxError.new(result)
    in Sthx::Ctx then result.root
    end
  end
end
