require "json"
require "./spec_helper"

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

json = json_grammar

def anify(json, string)
  return unless root = string.apply?(json)

  root.map(JSON::Any) do |tree, children|
    case tree.id
    when "root"   then children[0]
    when "number" then JSON::Any.new(tree["number:value"].to_f64)
    when "string" then JSON::Any.new(tree["string:value"])
    when "true"   then JSON::Any.new(true)
    when "false"  then JSON::Any.new(false)
    when "null"   then JSON::Any.new(nil)
    when "array"  then JSON::Any.new(children)
    when "pair"   then JSON::Any.new({tree["string:value"] => children[0]})
    when "object"
      JSON::Any.new(children.reduce({} of String => JSON::Any) { |a, b| a.merge!(b.as_h) })
    else
      raise NotImplementedError.new(tree.id)
    end
  end
end

describe Synthax do
  it "parses 10mb JSON in the same way as Crystal's JSON" do
    string = File.read("#{__DIR__}/data/10mb.json")
    (anify(json, string) == JSON.parse(string)).should be_true
  end
end
