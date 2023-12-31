# synthax

Synthax is a simple parser synthesizer for Crystal.

```crystal
# JSON grammar

ws = some(' ' | '\r' | '\n' | '\t')
digit = '0'..'9'
digits = many(digit)
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

json = element
```

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     synthax:
       github: homonoidian/synthax
   ```

2. Run `shards install`

## Usage

- Basic:

  ```crystal
  require "synthax"

  include Sthx::DSL

  # Write rules here...

  top = your_toplevel_rule

  "my string".apply(top)  # => Sthx::Ctx | Sthx::Err
  "my string".apply?(top) # => Sthx::Tree?
  "my string".apply!(top) # => Sthx::Tree
  ```

- A bit more sophisticated:

  ```crystal
  require "synthax"

  module Foo
    include Sthx::DSL

    GRAMMAR = grammar

    def self.grammar
      # Write rules here...

      your_toplevel_rule
    end
  end

  "my string".apply(Foo::GRAMMAR)  # => Sthx::Ctx | Sthx::Err
  "my string".apply?(Foo::GRAMMAR) # => Sthx::Tree?
  "my string".apply!(Foo::GRAMMAR) # => Sthx::Tree
  ```

- Rules and `Tree` are persistent and immutable. Linked list + path copying
  is used where appropriate, for storing children and mappings `Pf::Map` is
  used (hence the dependency on `permafrost`).

- For all else [see the docs](https://homonoidian.github.io/synthax/)

## `capture` and `keep`

A `Tree` has *children* (`0` to some `N` of them) and *mappings* (a string to string hash).

`capture(other, id)` lets you reroot the tree produced by *other* to a new `Tree`
node with the given *id*.

`keep(other, id)` takes *the string* matched by *other* and creates the mapping
of *id* to that string in the `capture` above. The tree produced by *other* is
thrown away.

## Performance

It's pretty horrible but okay for that phase where you don't have thousands upon
thousands of lines of code / frequent reparsing thereof. Fast parsing is the least
of concerns when you're prototyping a language/etc.

If you need to go through millions of characters routinely this is the worst shard
to pick I guess. I think recursive descent & a state-machine-ish lexer is better
for that purpose.

- No lexer means each character must be processed by rules on the heap. This also
  means that backtracking to explore another branch is much more expensive, requiring
  to repeatedly revisit parts of the string within a different context. The grammar
  driving the parsing instead of the string makes it a much more painful process,
  but this is the last place where I should write about that so let's move on.

- There is nothing fancy or theoretical done here.

For 10mb JSON example (including `anify`):

```text
        JSON.parse  11.38  ( 87.90ms) (± 4.67%)  33.9MB/op        fastest
Synthax JSON parse 974.49m (  1.03s ) (±15.50%)   418MB/op  11.67× slower
```

To test it yourself run `crystal run examples/json.cr -Dbenchmark --release`

- Memory usage is horrible due to `Sthx::Tree` overhead and children array
  overhead when converting to `JSON::Any`, plus `JSON::Any` itself of course.

- Parsing itself does not consume any memory because it's just recursively
  exploring a graph (if we don't count the call stack of course!) But you
  can't opt out of `Sthx::Tree` generation so haha live with it :)

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/homonoidian/synthax/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Alexey Yurchenko](https://github.com/homonoidian) - creator and maintainer
