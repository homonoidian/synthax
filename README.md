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

- See examples in the `examples/` directory.

## `capture` and `keep`

A `Tree` has *children* (`0` to some `N` of them) and *mappings* (a string to string hash).

`capture(other, id)` lets you store `capture`s and `keep`s produced by *other*
within a new `Tree` object with the given *id*. There is always an implicit
root tree. It is the parent of all top level captures and keeps.

`keep(other, id)` takes *the string* matched by *other* and creates the mapping
of *id* to that string in the current tree. The tree produced by *other* is
discarded. It's like named capture in regex.

## Performance

It's pretty horrible but okay for that phase where you don't have thousands upon
thousands of lines of code / frequent reparsing thereof. Fast parsing is the least
of concerns when you're prototyping a language/etc.

If you need to go through millions of characters routinely this is the worst shard
to pick I guess. I think recursive descent & a state-machine-ish lexer is better
for that purpose.

- No lexer means each character must be processed by rules on the heap. This also
  means that backtracking to explore another branch is much more expensive, requiring
  to repeatedly revisit same parts of the string within a different context. The
  grammar driving the parsing instead of the string makes it a much more painful
  process in general (because the string always knows better). But indexing ain't
  quick too.

- Nothing fancy or theoretical is done here. The thing is extremely simple. Take
  a look at the source code yourself.

For 10mb JSON example (including `anify`):

```text
        JSON.parse  11.34  ( 88.18ms) (± 4.69%)  33.9MB/op        fastest
Synthax JSON parse   1.14  (877.00ms) (±10.46%)   409MB/op   9.95× slower
```

To run the benchmark yourself use: `crystal run examples/json.cr -Dbenchmark --release`

- Memory usage is horrible due to `Sthx::Tree` overhead and children array
  overhead when converting to `JSON::Any`, plus `JSON::Any` itself of course.
  The children array cna be eliminated if you visit the `Sthx::Tree` yourself,
  without using the convenience `Sthx::Tree#map` methods. You always know more
  than those methods, so make use of that.

- Parsing itself does not consume any memory because it's just recursively
  exploring a graph (well, if we don't count the call stack of course!) But
  you can't opt out of `Sthx::Tree` generation so haha live with it :)

- I don't think it's currently possible to build something like that with generics,
  handling captures and all; it gets too nasty too soon. And generally, generics caused
  more Crystal language bugs than anything else for me, so I try not to venture
  too far into that territory.

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
