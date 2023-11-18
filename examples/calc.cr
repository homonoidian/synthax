require "../src/synthax"

include Sthx::DSL

def grammar
  ws = some(' ')
  digit = '0'..'9'
  alpha = ('A'..'Z') | ('a'..'z')
  alnum = digit | alpha
  number = many(digit)
  id = alpha & some(alnum)

  expr = ahead
  scale = ahead
  offset = ahead

  atom = ('(' & expr & ')') | capture(keep(id, "id"), "var") | capture(keep(number, "value"), "number")
  scale.put capture(atom & (ws & keep('*' | '/', "op") & ws & scale), "bin_op") | atom
  offset.put capture(scale & (ws & keep('+' | '-', "op") & ws & offset), "bin_op") | scale

  expr.put(ws & offset & ws)

  assign = keep(id, "name") & ws & '=' & ws & expr
  top = capture(assign) | expr
end

abstract class Node
  class Number < Node
    def initialize(@value : Float64)
    end

    def self.new(tree, children)
      new(tree["value"].to_f64)
    end

    def eval(env)
      @value
    end
  end

  class Var < Node
    def initialize(@id : String)
    end

    def self.new(tree, children)
      new(tree["id"])
    end

    def eval(env)
      env[@id]
    end
  end

  class BinOp < Node
    def initialize(@op : String, @a : Node, @b : Node)
    end

    def self.new(tree, children)
      new(tree["op"], children[0], children[1])
    end

    def eval(env)
      case @op
      when "+" then @a.eval(env) + @b.eval(env)
      when "-" then @a.eval(env) - @b.eval(env)
      when "*" then @a.eval(env) * @b.eval(env)
      when "/" then @a.eval(env) / @b.eval(env)
      else
        raise NotImplementedError.new(@op)
      end
    end
  end

  class Assign < Node
    def initialize(@name : String, @value : Node)
    end

    def self.new(tree, children)
      new(tree["name"], children[0])
    end

    def eval(env)
      env[@name] = @value.eval(env)
    end
  end

  class Root < Node
    def initialize(@node : Node)
    end

    def self.new(tree, children)
      new(children[0])
    end

    def eval(env)
      @node.eval(env)
    end
  end
end

g = grammar
env = {} of String => Float64

while (print "calc> "; input = gets)
  begin
    tree = input.apply!(g, exact: true)
    pp tree
    node = tree.map(Node)
    pp node
    puts node.eval(env)
  rescue e : Sthx::SyntaxError
    e.err.humanize(STDERR, color: Colorize.enabled?, readout: true)
    STDERR.puts
  rescue e : KeyError
    STDERR.puts("var not found")
  end
end
