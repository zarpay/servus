# Schema Validation

Servus can validate a service's arguments before execution and its result after execution using [JSON Schema](https://json-schema.org/understanding-json-schema). Validation is opt-in — services work without schemas. Servus uses the [`json-schema`](https://github.com/voxpupuli/json-schema) gem (draft-04 by default).

## Defining schemas

There are three ways to define schemas for a service. Servus checks them in this order — the first one found wins:

### 1. The `schema` DSL (recommended)

```ruby
class Treasury::TransferGold::Service < Servus::Base
  schema(
    arguments: {
      type: "object",
      required: ["from_account", "to_account", "gold_dragons"],
      properties: {
        from_account: { type: ["integer", "object"] },
        to_account: { type: ["integer", "object"] },
        gold_dragons: { type: "integer", minimum: 1 }
      }
    },
    result: {
      type: "object",
      required: ["transferred", "from_balance", "to_balance"],
      properties: {
        transferred: { type: "number" },
        from_balance: { type: "number" },
        to_balance: { type: "number" }
      }
    }
  )
end
```

You can define just one if you only need argument or result validation:

```ruby
schema arguments: {
  type: "object",
  required: ["from_account", "to_account", "gold_dragons"],
  properties: {
    gold_dragons: { type: "integer", minimum: 1 }
  }
}
```

### 2. Inline constants

::: warning Deprecated — will be removed in v1.0.0
Servus also checks for `ARGUMENTS_SCHEMA`, `RESULT_SCHEMA`, and `FAILURE_SCHEMA` constants on the service class. Migrate to the `schema` DSL before upgrading to v1.0.0.
:::

### 3. JSON files

For complex schemas, use JSON files. The framework looks for them at:

```
app/schemas/treasury/transfer_gold/arguments.json
app/schemas/treasury/transfer_gold/result.json
app/schemas/treasury/transfer_gold/failure.json
```

The path is derived from the service's class name — `Treasury::TransferGold::Service` becomes `treasury/transfer_gold`. The base directory defaults to `app/schemas` and can be configured:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.schemas_dir = "app/services"  # colocates schemas next to service files
  # or
  config.schemas_dir = "config/schemas" # keeps schemas outside of app/
end
```

Schemas are cached after first load. In development, clear the cache when you change a file-based schema:

```ruby
Servus::Support::Validator.clear_cache!
```

## What schemas buy you

### In production code

Argument validation runs before your `call` method. This means you can trust the types and shape of your inputs inside `call` — no defensive type checks, no nil guards on required fields, no "is this actually an integer?" conditionals. The schema already rejected bad input.

```ruby
# Without schemas — defensive code creeps in
def call
  return failure("amount required") unless @gold_dragons
  return failure("amount must be integer") unless @gold_dragons.is_a?(Integer)
  return failure("amount must be positive") unless @gold_dragons > 0

  # finally, the actual business logic...
end

# With schemas — call only contains business logic
def call
  enforce_sufficient_balance!(account: from_account, amount: @gold_dragons)

  from_account.withdraw!(@gold_dragons)
  to_account.deposit!(@gold_dragons)

  success(
    transferred: @gold_dragons,
    from_balance: from_account.balance,
    to_balance: to_account.balance
  )
end
```

Result validation runs after `call` returns. This catches bugs where the service returns data that doesn't match its contract — not just in tests, but in production. If someone changes the `call` method and forgets to return a required field, the schema catches it immediately.

### In test suites

With schemas in place, there's no need to write tests that verify a service rejects bad types or missing fields — the schema *is* the test. That entire category of specs disappears.

Adding `description` and `example` values to your schema properties also makes the schema a useful source of documentation. The test helpers come into play not when testing the service itself, but in other tests where you need to call a service or mock its result:

```ruby
schema(
  arguments: {
    type: "object",
    properties: {
      from_account: {
        type: "integer",
        description: "The account ID to withdraw from",
        example: 1
      },
      to_account: {
        type: "integer",
        description: "The account ID to deposit into",
        example: 2
      },
      gold_dragons: {
        type: "integer",
        description: "The number of gold dragons to transfer",
        minimum: 1,
        examples: [50, 75, 100]
      }
    }
  },
  result: {
    type: "object",
    properties: {
      transferred: {
        type: "number",
        description: "The amount that was transferred",
        example: 50
      },
      from_balance: {
        type: "number",
        description: "The sender's balance after the transfer",
        example: 950
      },
      to_balance: {
        type: "number",
        description: "The receiver's balance after the transfer",
        example: 550
      }
    }
  }
)
```

Then use the helpers wherever you need quick args or a mock result:

```ruby
# spec/spec_helper.rb
require 'servus/testing'

RSpec.configure do |config|
  config.include Servus::Testing::ExampleBuilders
end
```

```ruby
# In a controller spec — need to call the service with valid args
args = servus_arguments_example(Treasury::TransferGold::Service, gold_dragons: 100)
# => { from_account: 1, to_account: 2, gold_dragons: 100 }

# In an integration test — need to mock a service result
expected = servus_result_example(Treasury::TransferGold::Service)
allow(Treasury::TransferGold::Service).to receive(:call).and_return(expected)
```

The schema becomes the single source of truth for types, constraints, and test fixtures.

## Failure schemas

Services can validate structured data attached to failure responses. This is less common, but useful when callers depend on a specific failure shape:

```ruby
schema(
  failure: {
    type: "object",
    required: ["reason"],
    properties: {
      reason: { type: "string" },
      decline_code: { type: "string" }
    }
  }
)

# In your call method:
failure("Card declined", data: { reason: "insufficient_funds", decline_code: "do_not_honor" })
```

Failure validation is skipped when no failure schema is defined or when the failure has no `data:`.

## What happens on validation failure

Invalid arguments raise `ValidationError` before the service is instantiated. Invalid results raise `ValidationError` after `call` returns.

```ruby
Treasury::TransferGold::Service.call(from_account: 1, to_account: 2, gold_dragons: "fifty")
# => raises ValidationError: "fifty" is not of type integer
```

Both are programming errors, not business failures. The goal is never to catch or rescue a `ValidationError` — it's a signal that something upstream of the service is passing bad data, or the service itself is returning the wrong shape. An argument validation error means the caller has a bug. A result validation error means the service has a bug. Either way, the fix is in the code, not in error handling.

## Enforcing schema usage

By default, services work without schemas. If your team wants to require schemas across all services, enable the enforcement config flags:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.require_service_arguments_schema = true
  config.require_service_result_schema    = true
  config.require_event_payload_schema     = true
end
```

When enabled, calling a service without the corresponding schema raises `SchemaRequiredError`. The result schema is only enforced on successful responses — failure schemas remain optional.

### CI enforcement with `have_schema`

For teams that want to enforce schemas in CI without enabling runtime checks, use the `have_schema` matcher:

```ruby
RSpec.describe Treasury::TransferGold::Service do
  it { expect(described_class).to have_schema(:arguments) }
  it { expect(described_class).to have_schema(:result) }
end

RSpec.describe GoldTransferredHandler do
  it { expect(described_class).to have_schema(:payload) }
end
```

This catches missing schemas at test time without affecting production behavior.

## Three layers of validation

| Layer | Purpose | When it runs |
| --- | --- | --- |
| **Schema validation** (Servus) | Type safety and structure at the service boundary | Before and after `call` |
| **Business rules** (your `call` method) | Domain-specific constraints | During `call` |
| **Model validation** (ActiveRecord) | Database constraints | At persistence time |

Each layer has a different purpose — don't duplicate validation across them. Schemas catch type and shape errors. Business rules enforce domain logic. Model validation protects the database.
