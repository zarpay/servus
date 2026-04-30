# Responses

Every Servus service returns a `Response` object with three properties: `success?`, `data`, and `error`. The shape is always the same — callers never have to guess how to inspect the outcome.

## Success

When a service calls `success(...)`, the caller receives a `Response` with the data wrapped in a `DataObject`:

```ruby
result = Treasury::TransferGold::Service.call(
  from_account: crown_account,
  to_account: night_watch_account,
  gold_dragons: 50
)

result.success?          # => true
result.data.transferred  # => 50
result.data.from_balance # => 950
result.data.to_balance   # => 550
result.error             # => nil
```

### DataObject

Any hash passed to `success(...)` is deeply wrapped in a `DataObject`. This means nested values are accessible as methods at any depth:

```ruby
# Bracket access still works
result.data[:transferred]  # => 50

# Accessor access on nested hashes
result.data.transfer.from  # => "crown_account"
result.data.transfer.to    # => "night_watch"

# Arrays of hashes are wrapped too
result.data.entries.first.amount  # => 50
```

## Failure

When a service calls `failure(...)`, the caller receives a `Response` with an error and optionally structured data:

```ruby
result = Treasury::TransferGold::Service.call(
  from_account: crown_account,
  to_account: crown_account,
  gold_dragons: 50
)

result.success?        # => false
result.error.message   # => "Cannot transfer to the same account"
result.data            # => nil (unless data: was passed to failure)
```

### Failure with structured data

`failure` accepts an optional `data:` keyword for attaching structured information to the failure:

```ruby
failure("Card declined", data: { reason: "insufficient_funds", decline_code: "do_not_honor" })

# Caller can access:
result.error.message       # => "Card declined"
result.data.reason         # => "insufficient_funds"
result.data.decline_code   # => "do_not_honor"
```

### Error types

All errors inherit from `ServiceError` and map to HTTP status codes:

| Error class | HTTP status |
| --- | --- |
| `ServiceError` | 400 (base class) |
| `BadRequestError` | 400 |
| `UnauthorizedError` | 401 |
| `ForbiddenError` | 403 |
| `NotFoundError` | 404 |
| `ConflictError` | 409 |
| `ValidationError` | 422 |
| `TooManyRequestsError` | 429 |
| `InternalServerError` | 500 |
| `ServiceUnavailableError` | 503 |
| `GuardError` | 422 (with custom `code`) |

Servus includes error classes for every standard HTTP status (400–511). See `Servus::Support::Errors` for the full list.

Use the `type:` keyword to specify which error class a failure should use:

```ruby
failure("Account not found", type: NotFoundError)
```

::: info api_error
Every error has an `api_error` method that returns a hash ready for JSON API responses:

```ruby
result.error.api_error
# => { code: :not_found, message: "Account not found" }
```

This pairs well with Rails controller helpers — the error carries its own HTTP status and machine-readable code, so the controller doesn't have to interpret the failure.
:::

## error!

`error!` is for exceptional situations that should halt execution immediately. Unlike `failure`, it raises an exception:

```ruby
# failure returns a Response — execution continues
return failure("Insufficient funds")

# error! raises — execution stops
error!("Database corrupted", type: InternalServerError)
```

Use `failure` for expected business conditions. Use `error!` when something is genuinely wrong and the service cannot continue.

## Composition

If a downstream service fails and the calling service has no better context to add, return that response unchanged:

```ruby
def call
  reserve = Treasury::ReserveFunds::Service.call(account: @account, amount: @amount)
  return reserve unless reserve.success?

  # continue with reserved funds...
end
```

Responses travel through a workflow without re-wrapping. The original error type, message, and status code are preserved for the eventual caller.
