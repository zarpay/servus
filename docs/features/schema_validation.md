# Schema Validation

Servus provides optional JSON Schema validation for service arguments and results. Validation is opt-in - services work fine without schemas.

## How It Works

Define schemas as constants or JSON files. The framework validates arguments before execution and results after execution. Invalid data raises `ValidationError`.

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

For complex schemas, use JSON files instead of inline constants. Create files at:
- `app/schemas/services/service_name/arguments.json`
- `app/schemas/services/service_name/result.json`

Servus checks for inline constants first, then JSON files. Schemas are cached after first load for performance.

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
