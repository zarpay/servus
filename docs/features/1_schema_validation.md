# @title Features / 1. Schema Validation

# Schema Validation

Servus provides optional JSON Schema validation for service arguments and results. Validation is opt-in - services work fine without schemas.

## How It Works

Define schemas using the `schema` DSL method (recommended) or as constants. The framework validates arguments before execution and results after execution. Invalid data raises `ValidationError`.

### Preferred: Schema DSL Method

```ruby
class ProcessPayment::Service < Servus::Base
  schema(
    arguments: {
      type: "object",
      required: ["user_id", "amount"],
      properties: {
        user_id: { type: "integer", example: 123 },
        amount: { type: "number", minimum: 0.01, example: 100.0 }
      }
    },
    result: {
      type: "object",
      required: ["transaction_id", "new_balance"],
      properties: {
        transaction_id: { type: "string", example: "txn_abc123" },
        new_balance: { type: "number", example: 950.0 }
      }
    },
    failure: {
      type: "object",
      properties: {
        reason: { type: "string", example: "insufficient_funds" }
      }
    }
  )
end
```

**Pro tip:** Add `example` or `examples` keywords to your schemas. These values can be automatically extracted in tests using `servus_arguments_example()` and `servus_result_example()` helpers. See the [Testing documentation](../integration/testing.md#schema-example-helpers) for details.

You can define just one schema if needed:

```ruby
class SendEmail::Service < Servus::Base
  schema arguments: {
    type: "object",
    required: ["email", "subject"],
    properties: {
      email: { type: "string", format: "email" },
      subject: { type: "string" }
    }
  }
end
```

### Alternative: Inline Constants

Constants are still supported for backwards compatibility:

```ruby
class ProcessPayment::Service < Servus::Base
  ARGUMENTS_SCHEMA = {
    type: "object",
    required: ["user_id", "amount"],
    properties: {
      user_id: { type: "integer" },
      amount: { type: "number", minimum: 0.01 }
    }
  }.freeze

  RESULT_SCHEMA = {
    type: "object",
    required: ["transaction_id", "new_balance"],
    properties: {
      transaction_id: { type: "string" },
      new_balance: { type: "number" }
    }
  }.freeze

  FAILURE_SCHEMA = {
    type: "object",
    properties: {
      reason: { type: "string" }
    }
  }.freeze
end
```

## File-Based Schemas

For complex schemas, use JSON files instead of inline definitions. Create files at:
- `app/schemas/services/service_name/arguments.json`
- `app/schemas/services/service_name/result.json`
- `app/schemas/services/service_name/failure.json`

### Schema Lookup Precedence

Servus checks for schemas in this order:
1. **schema DSL method** (if defined)
2. **Inline constants** (ARGUMENTS_SCHEMA, RESULT_SCHEMA, FAILURE_SCHEMA)
3. **JSON files** (in schema_root directory)

Schemas are cached after first load for performance.

## Three Layers of Validation

**Schema Validation** (Servus): Type safety and structure at service boundaries

**Business Rules** (Service Logic): Domain-specific constraints during execution

**Model Validation** (ActiveRecord): Database constraints before persistence

Each layer has a different purpose - don't duplicate validation across layers.

## Failure Data Validation

Services can optionally attach structured data to failure responses using the `data:` keyword argument on `failure()`. When a `failure` schema is defined, this data is validated against it — just like success results are validated against `result` schemas.

```ruby
class ProcessPayment::Service < Servus::Base
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

  def call
    return failure("Card declined", data: { reason: "insufficient_funds", decline_code: "do_not_honor" })
  end
end
```

Failure data validation is skipped when:
- No `failure` schema is defined
- The failure response has no data (`data: nil`, the default)
- The response is a success

## Configuration

Change the schema file location if needed:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.schema_root = Rails.root.join('config/schemas')
end
```

Clear the schema cache during development when schemas change:

```ruby
Servus::Support::Validator.clear_cache!
```
