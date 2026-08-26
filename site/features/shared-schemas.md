# Shared Schemas

Servus schemas are declared inline, in the service that uses them. That keeps a
service's contract where you can see it. The cost is duplication: once a few
dozen services all take an amount, or return a timestamp, the same fragment of
JSON Schema gets copied everywhere — and drifts.

Shared schemas fix that without moving contracts out of the service. You
register a reusable fragment under a key, and services reference into it with a
standard JSON Schema `$ref`. A service that references a shared type is still
declaring that type explicitly; it just names it once instead of restating it.

## Registering a fragment

A fragment is a plain Ruby hash. Register it from an initializer:

```ruby
# config/initializers/servus_schemas.rb
Servus::Schema.register("core", {
  "$defs" => {
    "id" => { "type" => "integer", "minimum" => 1 },
    "amount" => {
      "type" => "integer",
      "minimum" => 0,
      "description" => "An amount in minor units",
      "example" => 1000
    },
    "timestamp" => { "type" => "string", "format" => "date-time" }
  }
})
```

That is the whole setup. There is no constant to name and no file to load,
because nothing ever references the fragment by constant — refs are strings,
resolved through the registry.

### As fragments grow

When one initializer stops being comfortable, split the fragments into files
under `config/schemas/` and require them. `config/` is not an autoload path, so
an explicit `require` is correct there:

```ruby
# config/schemas/core.rb
CoreSchema = { "$defs" => { ... } }.freeze
```

```ruby
# config/initializers/servus_schemas.rb
require Rails.root.join("config/schemas/core")

Servus::Schema.register("core", CoreSchema)
```

::: warning Don't put fragments in an autoloaded path
Avoid defining fragments in `app/`, or in `lib/` if you have
`config.autoload_lib` enabled. Zeitwerk only loads a constant when something
references it, and nothing ever references a fragment by name — so it would
never load, and never register. Explicitly `require`-ing an autoloaded file is
its own error. Keep fragments outside the autoload paths entirely.
:::

If a fragment genuinely has to live somewhere reloadable, register it from
`to_prepare`. Re-registering an identical value is a no-op, so this is safe to
run on every reload:

```ruby
Rails.application.config.to_prepare do
  Servus::Schema.register("core", CoreSchema::DEFS)
end
```

Registering a *different* value for an existing key replaces it and logs a
warning. During development that's a reload; anywhere else it usually means two
libraries are claiming the same key.

## Referencing a fragment

Two forms are supported:

```ruby
{ "$ref" => "#/core" }                # the whole fragment
{ "$ref" => "#/core/$defs/amount" }   # a path within it
```

Path segments are literal hash keys. There is no JSON Pointer escaping and no
array indexing. `$defs` has no special meaning to Servus — it's a conventional
place to keep definitions, and any key would work.

`Servus::Schema.ref` builds these for you, which avoids typos in the prefix and
separator:

```ruby
Servus::Schema.ref("core", "$defs", "amount")
# => { "$ref" => "#/core/$defs/amount" }
```

In a service:

```ruby
class Treasury::TransferGold::Service < Servus::Base
  schema arguments: {
    type: "object",
    required: ["from_account", "gold_dragons"],
    properties: {
      from_account:  { "$ref" => "#/core/$defs/id" },
      gold_dragons:  { "$ref" => "#/core/$defs/amount" },
      requested_at:  { "$ref" => "#/core/$defs/timestamp" }
    }
  }
end
```

## Reading the registry directly

Nothing about the registry is tied to services or events — it is a standalone
store that those two happen to consume. Anything in your app can register
fragments and read them back, which is what makes it usable as a single source
for contracts that have no service behind them, such as controller request and
response shapes.

`fetch` reads a fragment, or a definition within one, using the same addressing
a `$ref` uses:

```ruby
Servus::Schema.fetch("models::trade")
# => the whole fragment

Servus::Schema.fetch("models::trade", "$defs", "representation")
# => just that definition
```

A missing path raises `RefNotFoundError` listing what was available, rather than
returning nil the way `dig` would:

```ruby
Servus::Schema.fetch("models::trade", "$defs", "reprsentation")
# => RefNotFoundError: "$defs/reprsentation" could not be resolved in schema
#    fragment "models::trade": "reprsentation" is not present.
#    Available keys: "representation".
```

`fetch` returns fragments as authored, with refs intact. `resolve` is the
compiled counterpart — same addressing, but the result is self-contained and
ready to validate against. This is usually what you want outside a service:

```ruby
Servus::Schema.resolve("endpoints::trades::create", "$defs", "request")
# => { "type" => "object", "properties" => { "price" => { "type" => "integer" } } }
```

```ruby
# in a controller concern
def validate_request!
  schema = Servus::Schema.resolve("endpoints::trades::create", "$defs", "request")
  errors = JSON::Validator.fully_validate(schema, params.to_unsafe_h)
  render_unprocessable(errors) if errors.any?
end
```

Results are memoized, so asking repeatedly for the same address is cheap.
`Servus::Schema.compile` is also public if you need to compile a schema you
built yourself rather than one from the registry.

## Compiling everything as one asset

`compile_all` returns every registered fragment with all refs resolved, keyed by
name. Fragment keys stay addressable and the result serializes straight to JSON,
so it works as a build input for an API description, a docs site, client
codegen, or a CI freshness check:

```ruby
Servus::Schema.compile_all
# => {
#      "core" => { "$defs" => { "amount" => { "type" => "integer" } } },
#      "models::trade" => { "$defs" => { "representation" => { ... } } },
#      "endpoints::trades::create" => { ... }
#    }

File.write("schema.json", JSON.pretty_generate(Servus::Schema.compile_all))
```

Because it compiles everything, it also fails on any broken ref anywhere in the
registry — which makes it a useful thing to call in CI even if you throw the
result away.

## Overriding with sibling keys

Keys alongside a `$ref` override the fragment they resolve to. This is what
makes a shared fragment usable at a specific call site — you take the shape and
re-describe it:

```ruby
gold_dragons: {
  "$ref" => "#/core/$defs/amount",
  "description" => "Dragons to move from one vault to the other",
  "example" => 50
}
```

::: warning This differs from modern JSON Schema
In JSON Schema 2019-09 and later, keys beside a `$ref` are an *additional*
subschema applied as an intersection — both must hold. Servus treats them as an
override, because that is what shared fragments are actually used for. Under
draft-06, which `json-schema` implements, siblings to `$ref` are ignored
entirely, so there is no established behaviour being contradicted here.
:::

## What is not supported

| Form | Why |
| --- | --- |
| `#/$defs/thing` | Local refs resolve against the enclosing document. Servus resolves against registered fragments, so there is no document to resolve against. Register the definition as a fragment instead. |
| `https://example.com/s.json` | Remote refs would mean network access during validation. |
| `./other.json#/thing` | File refs were removed in 1.0 along with the file-based schema tier. |
| `#/core/items/0` | Segments are literal hash keys, not JSON Pointer tokens — no array indexing. |

Each raises `Servus::Schema::InvalidRefError` naming the specific form, rather
than failing later as a confusing lookup miss.

## Errors you will see

Every error names the ref, the schema being compiled, and the chain that led
there.

**A key that is not registered** — the important one. A lookup that returned
`nil` here would leave the service running with no validation at all, so this
raises instead:

```
Servus::Schema::UnknownKeyError:
  unknown schema key "cor". Did you mean: "core"?
  while compiling Treasury::TransferGold::Service arguments schema
```

**A path that does not exist**, listing what was there:

```
Servus::Schema::RefNotFoundError:
  "#/core/$defs/amonut" could not be resolved: "amonut" is not present in "core".
  Available keys: "amount", "id", "timestamp".
  while compiling Treasury::TransferGold::Service arguments schema
```

**A cycle**, naming every hop:

```
Servus::Schema::CircularReferenceError:
  circular $ref detected: #/a/node -> #/b/node -> #/a/node
```

## How it works

Compilation is lazy and memoized. A schema is compiled the first time it is
*read* — whether that read comes from validating a call, from the test example
builders, or from your own code asking a service for its contract. The result
is cached on the class.

Resolved fragments are memoized globally, so a fragment referenced by two
hundred services is expanded once, not two hundred times.

Registering a changed fragment invalidates every compiled schema that depends
on it, so you never have to track which services referenced what. In tests,
`Servus::Support::Validator.clear_cache!` clears the per-class cache.

Fragments may carry `$schema` and `$id` at their root — those are stripped when
the fragment is spliced into another schema, since `json-schema` raises on a
`$schema` URI it does not recognise.

## Testing

Fragments are registered process-wide, so a spec that registers one should
restore the registry afterwards:

```ruby
around do |example|
  snapshot = Servus::Schema.snapshot
  Servus::Schema.reset!
  example.run
ensure
  Servus::Schema.restore(snapshot)
end
```

Because `have_schema` now compiles, it also catches broken refs — a service
whose schema references an unregistered fragment fails the matcher rather than
passing and failing later in production:

```ruby
it { expect(described_class).to have_schema(:arguments) }
```

Examples declared inside a fragment flow through to the example builders, so a
shared fragment can carry its own examples and every service referencing it
inherits them:

```ruby
Servus::Schema.register("core", {
  "$defs" => { "amount" => { "type" => "integer", "example" => 1000 } }
})

servus_arguments_example(Treasury::TransferGold::Service)
# => { gold_dragons: 1000, ... }
```
