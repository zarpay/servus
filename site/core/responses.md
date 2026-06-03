# Result

`Servus::Result` is the value object that represents the outcome of an operation: either a `success?` carrying data, or a `failure?` carrying an error. Never both.

Every Servus service returns a `Result`. You can also construct one directly from any plain Ruby code that wants the same shape — there is no requirement to wrap your logic in a service class first.

```ruby
Servus::Result.success(user_id: 1)
# => #<Servus::Result success?=true data=#<DataObject user_id: 1> error=nil>

Servus::Result.failure("Card declined", type: Servus::Support::Errors::BadRequestError)
# => #<Servus::Result success?=false data=nil error=#<BadRequestError "Card declined">>
```

`Servus::Support::Response` is kept as an alias so existing code referencing the old constant keeps working unchanged.

## Outside a service

Anywhere in your codebase — controllers, jobs, plain POROs, scripts — you can produce and consume a `Result`:

```ruby
def import_rows(rows)
  return Servus::Result.failure("no rows") if rows.empty?

  imported = rows.map { |row| Row.create!(row) }
  Servus::Result.success(imported: imported.count)
end

result = import_rows(rows)

if result.success?
  puts "Imported #{result.data.imported}"
else
  puts "Error: #{result.error.message}"
end
```

`Servus::Result.success(data = nil)` takes any value. Hashes are wrapped in a `DataObject` (see below); everything else passes through unchanged.

`Servus::Result.failure(message = nil, data: nil, type: ServiceError)` mirrors the service-level `failure` DSL — same arguments, same defaults.

## Inside a service

Inside a `Servus::Base` service, the `success` and `failure` DSL methods are sugar over `Servus::Result.success` / `.failure`:

```ruby
class Treasury::TransferGold::Service < Servus::Base
  def call
    return failure("Cannot transfer to the same account") if @from == @to

    @from.withdraw!(@gold_dragons)
    @to.deposit!(@gold_dragons)

    success(
      transferred: @gold_dragons,
      from_balance: @from.balance,
      to_balance: @to.balance,
    )
  end
end
```

```ruby
result = Treasury::TransferGold::Service.call(
  from_account: crown_account,
  to_account: night_watch_account,
  gold_dragons: 50,
)

result.success?          # => true
result.data.transferred  # => 50
result.data.from_balance # => 950
result.data.to_balance   # => 550
result.error             # => nil
```

The return value is a `Servus::Result` — the same type you'd build by hand outside a service.

## DataObject

Any hash given to `success` / `Result.success` is deeply wrapped in a `DataObject`. Nested values are accessible as methods at any depth:

```ruby
# Bracket access still works
result.data[:transferred]  # => 50

# Accessor access on nested hashes
result.data.transfer.from  # => "crown_account"
result.data.transfer.to    # => "night_watch"

# Arrays of hashes are wrapped too
result.data.entries.first.amount  # => 50
```

## Failure with structured data

`failure` accepts an optional `data:` keyword for attaching structured information to the failure:

```ruby
failure("Card declined", data: { reason: "insufficient_funds", decline_code: "do_not_honor" })

# Caller can access:
result.error.message       # => "Card declined"
result.data.reason         # => "insufficient_funds"
result.data.decline_code   # => "do_not_honor"
```

The same shape works from `Servus::Result.failure` outside a service.

## Error types

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
Servus::Result.failure("Account not found", type: Servus::Support::Errors::NotFoundError)
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

`error!` is for exceptional situations inside a service that should halt execution immediately. Unlike `failure`, it raises an exception:

```ruby
# failure returns a Result — execution continues
return failure("Insufficient funds")

# error! raises — execution stops
error!("Database corrupted", type: InternalServerError)
```

Use `failure` for expected business conditions. Use `error!` when something is genuinely wrong and the service cannot continue. `error!` is a service-only DSL; outside a service, raise the error class directly.

## Composition

If a downstream service fails and the calling service has no better context to add, return that result unchanged:

```ruby
def call
  reserve = Treasury::ReserveFunds::Service.call(account: @account, amount: @amount)
  return reserve unless reserve.success?

  # continue with reserved funds...
end
```

Results travel through a workflow without re-wrapping. The original error type, message, and status code are preserved for the eventual caller.
