module Sthx
  class Tree
    # Returns the capture id of this tree (see `Rule.capture`).
    getter id : String

    # Returns the index of the first character of this tree in the
    # source string.
    getter begin : Int32

    def initialize(@id, @begin, @span = 0,
                   @children = Pf::Map(Int32, Tree).new,
                   @mappings = Pf::Map(String, String).new)
    end

    protected def visit(haystack : Hash(String, T.class)) : T forall T
      children = (0...@children.size).map { |index| @children[index].visit(haystack) }
      cls = haystack[@id]
      cls.new(self, children)
    end

    # Returns the index of the last character of this tree in the
    # source string.
    def end : Int32
      @begin + @span
    end

    # Returns the value of the given *mapping* on this tree. See `Rule.keep`.
    # For examples see `map`.
    def [](mapping : String) : String
      @mappings[mapping]
    end

    # Returns the value of the given *mapping* on this tree. Returns nil if
    # the mapping does not exist. See `Rule.keep`. For examples see `map`.
    def []?(mapping : String) : String?
      @mappings[mapping]?
    end

    # Returns *index*-th child of this tree.
    def [](index : Int) : Tree
      @children[index]
    end

    # Returns *index*-th child of this tree, or `nil` if this tree has no
    # child at *index*.
    def []?(index : Int) : Tree?
      @children[index]?
    end

    # :nodoc:
    def with(k : String, v : String)
      Tree.new(@id, @begin, @span, @children, @mappings.assoc(k, v))
    end

    # :nodoc:
    def span(*, to reader : Char::Reader) : Tree
      Tree.new(@id, @begin, reader.pos - @begin, @children, @mappings)
    end

    # :nodoc:
    def adopt(child : Tree) : Tree
      Tree.new(@id, @begin, @span, @children.assoc(@children.size, child), @mappings)
    end

    # Converts `self` into subclass instances of the given class *cls*.
    #
    # - All nonabstract subclasses of *cls* are studied
    # - Their names are converted to snake case: e.g. `BinOp` becomes `bin_op`
    # - `Tree`s whose `id` matches the snake case name of some subclass *s* are passed
    #   to *s*'s `new` method like so: `s.new(tree : Tree, children : Array(T))`.
    #
    # Please note that there is always an implicit *root* node. You must handle
    # it as well. See `String#apply?`.
    #
    # ```
    # abstract class ASTree
    #   class Num < self
    #     def initialize(@value : Float64)
    #     end
    #
    #     def self.new(tree : Tree, children : Array(ASTree))
    #       new(tree.string.to_f64)
    #     end
    #
    #     def result
    #       @value
    #     end
    #   end
    #
    #   class BinOp < self
    #     def initialize(@operator : String, @a : ASTree, @b : ASTree)
    #     end
    #
    #     def self.new(tree : Tree, children : Array(ASTree))
    #       new(tree["op"], children[0], children[1])
    #     end
    #
    #     def result
    #       case @operator
    #       when "+" then @a.result + @b.result
    #       when "-" then @a.result - @b.result
    #       when "*" then @a.result * @b.result
    #       when "/" then @a.result / @b.result
    #       else
    #         0.0
    #       end
    #     end
    #   end
    #
    #   class Root < self
    #     def initialize(@exps : Array(ASTree))
    #     end
    #
    #     def self.new(tree : Tree, children : Array(ASTree))
    #       new(children)
    #     end
    #
    #     def result
    #       (exp = @exps.last?) ? exp.result : 0.0
    #     end
    #   end
    # end
    #
    # include DSL
    #
    # mul = ahead
    # add = ahead
    #
    # ws = (' ' | '\r' | '\n' | '\t')*(..)
    # num = ('0'..'9')*(1..)
    # value = capture(num) | '(' & ws & add & ws & ')'
    #
    # mul.put capture(value & ws & keep('*' | '/', "op") & ws & mul, "bin_op") | value
    # add.put capture(mul & ws & keep('+' | '-', "op") & ws & add, "bin_op") | mul
    #
    # e1 = "2 + 3 * 4"
    # e2 = "(2 + 3) * 4"
    #
    # results = {e1, e2}.map &.apply!(add).map(ASTree).result
    # results # => {14.0, 20.0}
    # ```
    def map(cls : T.class) : T forall T
      haystack = Hash(String, T.class).new

      {% for subclass in T.all_subclasses %}
        {% unless subclass.abstract? %}
          {% name = subclass.name.split("::")[-1].underscore %}
          haystack[{{name.id.stringify}}] = {{subclass.name}}
        {% end %}
      {% end %}

      visit(haystack)
    end

    # Converts `self` into instance(s)/subcloass instances of the given
    # class *cls*.
    #
    # Calls *fn* with `self` and the array of `self`'s children already
    # converted into instances of *cls* using *fn* recursively.
    #
    # Most of the times you'd want to consider the other overload `map(cls : T.class)`
    # instead, though.
    #
    # Please note that there is always an implicit *root* tree. You must handle
    # it as well. See `String#apply?`.
    #
    # ```
    # include DSL
    #
    # number = capture(('0'..'9')*(1..), "number")
    #
    # factor = ahead
    # factor.put(capture(number & keep('*' | '/', "kind") & factor, "op") | number)
    #
    # add = ahead
    # add.put(capture(factor & keep('+' | '-', "kind") & add, "op") | factor)
    #
    # if tree = "100+200*300".apply?(add)
    #   result = tree.map(Float64) do |tree, children|
    #     case tree.id
    #     when "root"   then next children[0]
    #     when "number" then next tree.string.to_f64
    #     when "op"
    #       case tree["kind"]
    #       when "+" then next children[0] + children[2]
    #       when "-" then next children[0] - children[2]
    #       when "*" then next children[0] * children[2]
    #       when "/" then next children[0] / children[2]
    #       end
    #     end
    #     0.0
    #   end
    #   result # => 60100.0
    # end
    # ```
    def map(cls : T.class, &fn : Tree, Array(T) -> T) : T forall T
      fn.call(self, (0...@children.size).map { |index| @children[index].map(cls, &fn) })
    end

    # Appends a string view of this tree to *io*.
    def inspect(io, indent = 0)
      ws = " " * indent
      io << ws << @id << " ⸢" << @begin << "-" << @begin + @span << "⸥ "
      unless @mappings.empty?
        io << '{'
        @mappings.join(io, ", ") do |(k, v)|
          io << '"' << k << "\" => "
          v.inspect(io)
        end
        io << '}'
      end
      io << '\n'
      (0...@children.size).each do |index|
        @children[index].inspect(io, indent: indent + 2)
      end
    end

    # Same as `inspect`.
    def to_s(io)
      inspect(io)
    end
  end
end
