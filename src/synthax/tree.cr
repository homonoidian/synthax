module Sthx
  class Tree
    private struct ChildrenIndexable
      include Indexable(Tree)

      def initialize(@children : Pf::Map(Int32, Tree))
      end

      def size : Int
        @children.size
      end

      def unsafe_fetch(index : Int) : Tree
        @children[index]
      end
    end

    # Returns the capture id of this tree (see `Rule.capture`).
    getter id : String

    # Returns the index of the first *character* (not byte!) of this tree
    # in the source string.
    getter begin : Int32

    # Returns the amount of characters (not bytes!) that this tree matches
    # in the source string.
    getter span : Int32

    def initialize(
      @id, @begin,
      @span = 0,
      @children = Pf::Map(Int32, Tree).new,
      @attributes = Pf::Map(String, String).new
    )
    end

    protected def visit(haystack : Hash(String, T.class)) : T forall T
      children = (0...@children.size).map { |index| @children[index].visit(haystack) }
      cls = haystack[@id]
      cls.new(self, children)
    end

    # :nodoc:
    def terminate(*, at index : Int) : Tree
      raise ArgumentError.new unless index > @begin

      Tree.new(@id, @begin, index - @begin, @children, @attributes)
    end

    # Returns the index of the *character* (not byte!) immediately following
    # the last character of this tree in the source string.
    def end : Int32
      @begin + @span
    end

    # Returns an `Indexable` over this tree's children.
    #
    # ```
    # # tree : Tree
    #
    # tree.children[0]   # => Tree
    # tree.children.size # => Int
    # tree.children.each do |child|
    #   pp child # => Tree
    # end
    #
    # # ...
    # ```
    def children : Indexable(Tree)
      ChildrenIndexable.new(@children)
    end

    # Returns the value of an attribute with the given *name*, if one is defined
    # on this tree. Otherwise, returns `nil`. Attributes are usually defined using
    # `Rule.keep`.
    def getattr?(name : String) : String?
      @attributes[name]?
    end

    # Same as `getattr?`, but raises `KeyError` if the attribute was not found.
    def getattr(name : String) : String
      getattr?(name) || raise KeyError.new
    end

    # Returns a copy of this tree where an attribute with the given *name*
    # has the value of *value*.
    def setattr(name : String, value : String)
      Tree.new(@id, @begin, @span, @children, @attributes.assoc(name, value))
    end

    # :nodoc:
    def dig?(step : Int) : Tree?
      @children[step]?
    end

    # :nodoc:
    def dig?(step : String) : Tree?
      children.find { |child| child.id == step }
    end

    # Follows deeper into the tree guided by the provided *steps*. Returns the
    # final tree, or `nil` if could not follow one of the steps.
    #
    # The following types of steps are available:
    #
    # - `String`: follow to a child whose id is equal to the given string.
    # - `Int`: follow to a child whose index in the parent tree is equal to
    #   the given integer.
    #
    # ```
    # # tree : Tree
    # tree.dig?("range", ":begin:", 0) # => Tree?
    # tree.dig?("foo", 0, "bar")       # => Tree?
    # ```
    def dig?(*steps) : Tree?
      return unless tree = dig?(steps[0])

      tree.dig?(*steps[1..])
    end

    # Same as `dig?`, but raises `KeyError` when it is impossible to follow one
    # of the specified *steps*.
    #
    # ```
    # # tree : Tree
    # tree.dig("range", ":begin:", 0) # => Tree
    # tree.dig("foo", 0, "bar")       # => Tree
    # ```
    def dig(*steps) : Tree
      dig?(*steps) || raise KeyError.new
    end

    # :nodoc:
    def adopt(child : Tree) : Tree
      Tree.new(@id, @begin, @span, @children.assoc(@children.size, child), @attributes)
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
      fn.call(self, children.map { |child| child.map(cls, &fn) })
    end

    protected def inspect(io, inner, outer)
      io << inner << " " << @id << " ⸢" << self.begin << "-" << self.end << '⸥'
      unless @attributes.empty?
        io << " "
        @attributes.join(io, ' ') do |(k, v)|
          io << k << "="
          v.inspect(io)
        end
      end
      io << '\n'

      remaining = @children.size

      children.each do |child|
        if remaining == 1
          io << outer << "└─"
          new_outer = outer + "   "
        else
          io << outer << "├─"
          new_outer = outer + "│  "
        end
        child.inspect(io, inner, new_outer)
        remaining -= 1
      end
    end

    # Appends a multiline string view of this tree to *io*.
    def inspect(io)
      inspect(io, inner: "", outer: " ")
    end

    # Same as `inspect`.
    def to_s(io)
      inspect(io)
    end
  end
end
