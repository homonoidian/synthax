require "json"
require "../src/synthax"

include Sthx::DSL

def json_grammar
  ws = some(' ' | '\r' | '\n' | '\t')
  digit = '0'..'9'
  digits = digit*(1..)
  integer = maybe('-') & ('0' | ('1'..'9') & some(digit))
  fraction = '.' & digits
  exponent = ('E' | 'e') & ('+' | '-') & digits
  number = keep(integer & maybe(fraction) & maybe(exponent), "number:value")
  hex = digit | ('A'..'F') | ('a'..'f')
  escape = '"' | '\\' | '/' | 'b' | 'f' | 'n' | 'r' | 't' | ('u' & hex & hex & hex & hex)
  character = ((0x0020..0x10FFFF) - '"' - '\\') | ('\\' & escape)
  string = '"' & keep(some(character), "string:value") & '"'
  value = ahead
  element = ws & value & ws
  elements = sep(element, by: ',')
  array = '[' & (elements | ws) & ']'
  member = capture(ws & string & ':' & element, "pair")
  members = sep(member, by: ',')
  object = '{' & (members | ws) & '}'
  value.put \
    capture(object) |
    capture(array) |
    capture(string) |
    capture(number) |
    lit("true") |
    lit("false") |
    lit("null")
  element
end

JSON_G = json_grammar

def parse(string)
  string.apply!(JSON_G, exact: true).map(JSON::Any) do |tree, children|
    case tree.id
    when "root"   then children[0]
    when "number" then JSON::Any.new(tree.getattr("number:value").to_f64)
    when "string" then JSON::Any.new(tree.getattr("string:value"))
    when "true"   then JSON::Any.new(true)
    when "false"  then JSON::Any.new(false)
    when "null"   then JSON::Any.new(nil)
    when "array"  then JSON::Any.new(children)
    when "pair"   then JSON::Any.new({tree.getattr("string:value") => children[0]})
    when "object"
      JSON::Any.new(children.reduce({} of String => JSON::Any) { |a, b| a.merge!(b.as_h) })
    else
      raise NotImplementedError.new(tree.id)
    end
  end
end

{% if flag?(:benchmark) %}
  require "benchmark"

  string = File.read("#{__DIR__}/../spec/data/10mb.json")

  Benchmark.ips do |x|
    x.report("JSON.parse") do
      JSON.parse(string)
    end

    x.report("Synthax JSON parse") do
      parse(string)
    end
  end
{% else %}
  while (print "json> "; input = gets)
    begin
      pp parse(input)
    rescue e : Sthx::SyntaxError
      e.err.humanize(STDOUT, color: Colorize.enabled?)
      puts
    end
  end
{% end %}
