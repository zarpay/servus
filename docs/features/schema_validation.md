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
        user_id: { type: "integer" },
        amount: { type: "number", minimum: 0.01 }
      }
    },
    result: {
      type: "object",
      required: ["transaction_id", "new_balance"],
      properties: {
        transaction_id: { type: "string" },
        new_balance: { type: "number" }
      }
    }
  )
end
```

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
end
```

## File-Based Schemas

For complex schemas, use JSON files instead of inline definitions. Create files at:
- `app/schemas/services/service_name/arguments.json`
- `app/schemas/services/service_name/result.json`

### Schema Lookup Precedence

Servus checks for schemas in this order:
1. **schema DSL method** (if defined)
2. **Inline constants** (ARGUMENTS_SCHEMA, RESULT_SCHEMA)
3. **JSON files** (in schema_root directory)

Schemas are cached after first load for performance.

## Three Layers of Validation

**Schema Validation** (Servus): Type safety and structure at service boundaries

**Business Rules** (Service Logic): Domain-specific constraints during execution

**Model Validation** (ActiveRecord): Database constraints before persistence

Each layer has a different purpose - don't duplicate validation across layers.

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
