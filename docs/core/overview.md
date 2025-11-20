# Servus Overview

Servus is a lightweight framework for implementing service objects in Ruby applications. It extracts business logic from controllers and models into testable, single-purpose classes with built-in validation, error handling, and logging.

## Core Concepts

### The Service Pattern

Services encapsulate one business operation. Each service inherits from `Servus::Base`, implements `initialize` and `call`, and returns a `Response` object indicating success or failure.

```ruby
class ProcessPayment::Service < Servus::Base
  def initialize(user_id:, amount:)
    @user_id = user_id
    @amount = amount
  end

  def call
    user = User.find(@user_id)
    return failure("Insufficient funds") unless user.balance >= @amount

    user.update!(balance: user.balance - @amount)
    success(user: user, new_balance: user.balance)
  end
end

# Usage
result = ProcessPayment::Service.call(user_id: 1, amount: 50)
result.success? # => true
result.data     # => { user: #<User>, new_balance: 950 }
```

### Response Objects

Services return `Response` objects instead of raising exceptions for business failures. This makes success and failure paths explicit and enables service composition without exception handling.

```ruby
result = SomeService.call(params)
if result.success?
  result.data  # Hash or object returned by success()
else
  result.error # ServiceError instance
  result.error.message
  result.error.api_error # { code: :symbol, message: "string" }
end
```

### Optional Schema Validation

Services can define JSON schemas for arguments and results. Validation happens automatically before/after execution but is entirely optional.

```ruby
class Service < Servus::Base
  ARGUMENTS_SCHEMA = {
    type: "object",
    required: ["user_id", "amount"],
    properties: {
      user_id: { type: "integer" },
      amount: { type: "number", minimum: 0.01 }
    }
  }.freeze

  # Or use external JSON file: app/schemas/services/service_name/arguments.json
end
```

## When to Use Servus

**Good fits**: Multi-step workflows, operations spanning multiple models, external API calls, background jobs, complex business logic.

**Poor fits**: Simple CRUD, single-model operations, operations tightly coupled to one model.

## Framework Integration

Servus core works in any Ruby application. Rails-specific features (async via ActiveJob, controller helpers, generators) are optional additions. Services work without any configuration - just inherit from `Servus::Base` and implement your logic.
