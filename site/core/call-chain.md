# Call Chain

When you call `Service.call(**args)`, the framework runs a fixed sequence around your `call` instance method. This page explains each step, what happens when it fails, and what you can configure.

## Always use `.call`

```ruby
# Correct — runs the full lifecycle
result = Treasury::TransferGold::Service.call(
  from_account: crown_account,
  to_account: wall_account,
  gold_dragons: 50
)
```

```ruby
# Bypasses the lifecycle — no validation, no logging, no events
service = Treasury::TransferGold::Service.new(
  from_account: crown_account,
  to_account: wall_account,
  gold_dragons: 50
)
result = service.call
```

Instantiating directly skips everything the framework provides.

## The chain, step by step

### 1. Log the call

The framework logs the service class name and arguments at `info` level before anything else runs. This means even calls that fail validation are recorded.

```
Calling Treasury::TransferGold::Service with args: {:from_account=>1, :to_account=>2, :gold_dragons=>50}
```

### 2. Validate arguments

If the service defines `schema(arguments: ...)`, the arguments are validated against that JSON Schema. Invalid arguments raise a `ValidationError` — the service is never instantiated.

```ruby
schema(
  arguments: {
    type: "object",
    required: ["from_account", "to_account", "gold_dragons"],
    properties: {
      from_account: { type: ["integer", "object"] },
      to_account: { type: ["integer", "object"] },
      gold_dragons: { type: "integer", minimum: 1 }
    }
  }
)
```

If no schema is defined, this step is skipped.

Because validation runs before your code, the `call` method can trust that the arguments are the right type and shape. No defensive type checks, no nil guards on required fields — the schema already rejected bad input. This keeps `call` focused on the business action itself.

### 3. Instantiate the service

The framework calls `new(**args)`, which runs your `initialize`. Instance variables are set here — this is where `lazily` resolvers store their raw values (but don't resolve yet).

### 4. Run your `call` method

Your `call` method runs inside two wrappers:

- **A benchmark timer** that records how long execution takes.
- **A guard catch block** — if any `enforce_*!` guard fails, it throws `:guard_failure` with a `GuardError`. The framework catches it and converts it to a failure `Response` automatically.

This is the only step you write. Everything else is handled by the framework.

### 5. Log the result

The framework logs the outcome with the duration from the benchmark timer:

```
Treasury::TransferGold::Service succeeded in 0.013s
```

On failure:

```
Treasury::TransferGold::Service failed in 0.008s with error: Insufficient funds
```

### 6. Validate the result

If the service defines a result schema, the data inside a successful `Response` is validated against it at runtime — every time the service runs.

```ruby
schema(
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
```

A schema violation raises `ValidationError`. This catches bugs where the service returns data that doesn't match its contract — not just in tests, but in production. If someone changes the `call` method and forgets to return a required field, the schema catches it immediately.

Just like argument validation gives you confidence inside `call`, result validation gives callers confidence in what they receive. The response shape is guaranteed, not assumed.

::: tip Failure schemas
Failure responses skip result validation. If a `schema(failure: ...)` is defined, failure data is validated against that schema instead. This is less commonly used, but useful when callers depend on structured failure data.

```ruby
schema(
  failure: {
    type: "object",
    properties: {
      reason: { type: "string" }
    }
  }
)

# In your call method:
failure("Card declined", data: { reason: "insufficient_funds" })
```
:::

### 7. Emit events

If the service declares events, the framework fires them after validation passes.

```ruby
class Service < Servus::Base
  emits :gold_transferred, on: :success
  emits :transfer_failed, on: :failure
  emits :transfer_error, on: :error!
end
```

The payload depends on the trigger:

- **On success** — the payload is `result.data` (the hash you passed to `success(...)`)
- **On failure** — the payload is `result.error` (the `ServiceError` instance)
- **On error!** — the payload is `result.error`. The event is emitted synchronously *before* the exception is raised, so handlers can enqueue async work (like alerting) before the error propagates

Events only fire after result validation, so handlers never receive invalid data. How handlers subscribe to these events is covered in [Event Bus](/features/event-bus).

## Exception handling

Two rescue blocks wrap the entire chain:

### `ValidationError`

Logged and re-raised. These are programming errors — bad arguments or a result that violates its schema — not business failures. They should never be caught by callers; they indicate a bug in the service or its caller.

```ruby
# Caller passes a string where the schema requires an integer
Treasury::TransferGold::Service.call(from_account: 1, to_account: 2, gold_dragons: "fifty")
# => raises ValidationError: "fifty" is not of type integer

# Log output:
# Treasury::TransferGold::Service validation error: "fifty" is not of type integer
```

### `StandardError`

Any uncaught exception from your `call` method is logged and re-raised. The log includes the exception class and message, which helps trace failures without swallowing them.

If you want to convert specific exceptions into failure responses instead of letting them propagate, use [`rescue_from`](/features/error-handling):

```ruby
class Service < Servus::Base
  rescue_from ActiveRecord::RecordNotFound, use: NotFoundError
  rescue_from Net::HTTPError, Timeout::Error, use: ServiceUnavailableError
end

# Without rescue_from:
# Treasury::TransferGold::Service uncaught exception: ActiveRecord::RecordNotFound - Couldn't find Account with 'id'=999

# With rescue_from:
# result.success?       # => false
# result.error.message  # => "[ActiveRecord::RecordNotFound]: Couldn't find Account with 'id'=999"
```

With `rescue_from`, the exception becomes a failure `Response` — the caller gets `result.success? # => false` instead of an exception.

## `.call_async`

[`.call_async(**args)`](/features/async-execution) enqueues the same lifecycle through ActiveJob. The service runs identically — the only difference is when and where.
