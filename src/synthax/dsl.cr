module Sthx
  module DSL
    extend self

    # See the same method in `Rule`.
    delegate :ahead, :capture, :keep, to: Rule

    # Returns a literal *string* capture rule (capture whose name is the
    # same as the captrued *string*).
    #
    # ```
    # boolean = lit("true") | lit("false")
    #
    # "true".apply!(boolean)
    # # => root ⸢0-4⸥
    # #      true ⸢0-4⸥
    #
    # "false".apply!(boolean)
    # # => root ⸢0-5⸥
    # #      false ⸢0-5⸥
    # ```
    def lit(string : String) : Rule
      capture(string, string)
    end

    # Creates a capture with the same name as the given *var* (which should
    # be the name of a variable holding the captured rule).
    #
    # ```
    # boolean = keep("true" | "false", "literal")
    # null = "null"
    # value = capture(boolean) | capture(null)
    #
    # "true".apply!(value)
    # # => root ⸢0-4⸥
    # #      boolean ⸢0-4⸥ {"literal" => "true"}
    #
    # "false".apply!(value)
    # # => root ⸢0-5⸥
    # #      boolean ⸢0-5⸥ {"literal" => "false"}
    #
    # "null".apply!(value)
    # # => root ⸢0-4⸥
    # #      null ⸢0-4⸥
    # ```
    macro capture(var)
      {% unless var.is_a?(Var) %}
        {% raise "expected an id (got '#{var}'), did you perhaps mean capture(..., ...)?" %}
      {% end %}
      capture({{var}}, "{{var.id}}")
    end

    # Returns a rule that will match if *exp* (see `Rule.from`) matches zero
    # or one times.
    #
    # ```
    # xyzzy = "xy" & maybe('z') & "zy"
    #
    # "xyzy".apply?(xyzzy)  # => Tree
    # "xyzzy".apply?(xyzzy) # => Tree
    # "xyy".apply?(xyzzy)   # => nil
    # ```
    def maybe(exp) : Rule
      exp*(0...1)
    end

    # Returns a rule that will match *exp* zero or more times.
    #
    # ```
    # foos = "foo" & some('s')
    #
    # "foo".apply?(foos)   # => Tree
    # "foos".apply?(foos)  # => Tree
    # "fooss".apply?(foos) # => Tree
    # # ...
    # ```
    def some(exp) : Rule
      exp*(..)
    end

    # Returns a rule that will match *exp* one or more times.
    # ```
    # foos = "foo" & many('s')
    #
    # "foo".apply?(foos)   # => nil
    # "foos".apply?(foos)  # => Tree
    # "fooss".apply?(foos) # => Tree
    # # ...
    # ```
    def many(exp) : Rule
      exp*(1..)
    end

    # Returns a rule that will match a list of one or more *exp*s (see `Rule.from`)
    # separated by *sexp*s (same).
    #
    # ```
    # foo = "foo"
    # foos = sep(foo, by: some(' ') & "and" & some(' '))
    #
    # "".apply?(foos)                    # => nil
    # "foo".apply?(foos)                 # => Tree
    # "foo and foo".apply?(foos)         # => Tree
    # "foo and foo and foo".apply?(foos) # => Tree
    # ```
    def sep(exp, *, by sexp)
      exp & some(sexp & exp)
    end
  end
end
