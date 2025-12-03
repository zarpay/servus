# @title Core / 2. Architecture

# Architecture

Servus wraps service execution with automatic validation, logging, and error handling. When you call `Service.call(**args)`, the framework orchestrates these concerns transparently.

## Execution Flow

```
Arguments → Validation → Service#call → Result Validation → Event Emission → Logging → Response
                ↓                              ↓                   ↓              ↓
          ValidationError                ValidationError      EventHandlers   Benchmark
```

The framework intercepts the `.call` class method to inject cross-cutting concerns before and after your business logic runs. Your `call` instance method contains only business logic - validation, logging, event emission, and timing happen automatically.

## Core Components

**Servus::Base** (`lib/servus/base.rb`): Foundation class providing `.call()` orchestration and response helpers (`success`, `failure`, `error!`)

**Support::Response** (`lib/servus/support/response.rb`): Immutable result object with `success?`, `data`, and `error` attributes

**Support::Validator** (`lib/servus/support/validator.rb`): JSON Schema validation for arguments (before execution) and results (after execution). Schemas are cached after first load.

**Support::Logger** (`lib/servus/support/logger.rb`): Automatic logging at DEBUG (calls with args), INFO (success), WARN (failures), ERROR (exceptions)

**Support::Rescuer** (`lib/servus/support/rescuer.rb`): Declarative exception handling via `rescue_from` class method

**Support::Errors** (`lib/servus/support/errors.rb`): HTTP-aligned error hierarchy (ServiceError, NotFoundError, ValidationError, etc.)

**Events::Emitter** (`lib/servus/events/emitter.rb`): DSL for declaring events that services emit on success/failure

**Events::Bus** (`lib/servus/events/bus.rb`): Central event router using ActiveSupport::Notifications for thread-safe dispatch

**EventHandler** (`lib/servus/event_handler.rb`): Base class for handlers that subscribe to events and invoke services

## Extension Points

### Schema Validation

Use the `schema` DSL method to define JSON Schema validation for arguments and results:

```ruby
class Service < Servus::Base
  schema(
    arguments: { type: "object", required: ["user_id"] },
    result: { type: "object", required: ["user"] }
  )
end
```

### Declarative Error Handling

Use `rescue_from` to convert exceptions into failures. Provide a custom error type or use a block for custom handling.

```ruby
class Service < Servus::Base
  # Default error type
  rescue_from Net::HTTPError, Timeout::Error, use: ServiceUnavailableError

  # Custom handling with block
  rescue_from ActiveRecord::RecordInvalid do |exception|
    failure("Validation failed: #{exception.message}", type: ValidationError)
  end
end
```

### Support Classes

Create helper classes in `app/services/service_name/support/*.rb`. These are namespaced to your service.

```
app/services/process_payment/
├── service.rb
└── support/
    ├── payment_gateway.rb
    └── receipt_formatter.rb
```

## Async Execution

`Service.call_async(**args)` enqueues execution via ActiveJob. The service runs identically whether called sync or async.

```ruby
ProcessPayment::Service.call_async(
  user_id: 1,
  amount: 50,
  queue: :critical,
  wait: 5.minutes
)
```

## Event-Driven Architecture

Services can emit events that trigger downstream handlers. This decouples services from their side effects.

```ruby
# Service emits events
class CreateUser::Service < Servus::Base
  emits :user_created, on: :success
end

# Handler reacts to events
class UserCreatedHandler < Servus::EventHandler
  handles :user_created

  invoke SendWelcomeEmail::Service, async: true do |payload|
    { user_id: payload[:user_id] }
  end
end
```

See {file:docs/features/5_event_bus.md Event Bus} for full documentation.

## Performance

- Schema loading: Cached per class after first use
- Validation overhead: ~1-5ms when schemas defined
- Logging overhead: ~0.1ms per call
- Total framework overhead: < 10ms per service call
