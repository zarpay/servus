# Error Handling

Servus distinguishes between two kinds of problems: business failures that callers should handle, and system exceptions that indicate bugs or infrastructure issues.

## `failure()` — expected business conditions

Use `failure` when the domain expects the condition — insufficient funds, invalid state, a rule that prevents the action. The caller receives a `Response` and can branch on `success?`.

```ruby
def call
  return failure("Cannot transfer to the same account") if from_account == to_account
  return failure("Insufficient funds") if from_account.balance < @gold_dragons

  from_account.withdraw!(@gold_dragons)
  to_account.deposit!(@gold_dragons)

  success(
    transferred: @gold_dragons,
    from_balance: from_account.balance,
    to_balance: to_account.balance
  )
end
```

### Failure with a specific error type

Use `type:` to attach an HTTP-aligned error class. This is especially useful when the response flows through to a controller:

```ruby
return failure("Account not found", type: NotFoundError)       # 404
return failure("Not authorized", type: ForbiddenError)         # 403
return failure("Rate limit exceeded", type: TooManyRequestsError)  # 429
```

::: info Controller integration
When using Servus's [controller helpers](/rails/controllers), the error type's `http_status` and `api_error` are used to render the response automatically. A `failure("Account not found", type: NotFoundError)` becomes a 404 JSON response without any branching in the controller.
:::

### Failure with structured data

Use `data:` to attach structured information to the failure. The data is wrapped in a `DataObject` just like success data:

```ruby
failure("Card declined", data: { reason: "insufficient_funds", decline_code: "do_not_honor" })

# Caller can access:
result.error.message     # => "Card declined"
result.data.reason       # => "insufficient_funds"
result.data.decline_code # => "do_not_honor"
```

## `error!()` — exceptional halts

Use `error!` when something is genuinely broken and the service cannot continue. Unlike `failure`, it raises an exception:

```ruby
def call
  error!("Ledger integrity check failed", type: InternalServerError) unless ledger.balanced?

  # This line never runs if the ledger is broken
  from_account.withdraw!(@gold_dragons)
end
```

`failure` returns a `Response` — execution continues. `error!` raises — execution stops. Use `failure` for business conditions the caller can handle. Use `error!` for invariants that should never be normalized away.

## `rescue_from` — declarative exception handling

`rescue_from` converts specific exceptions into failure responses instead of letting them propagate. This keeps your `call` method free of begin/rescue blocks.

### With an error type

Map one or more exception classes to an error type:

```ruby
class Treasury::TransferGold::Service < Servus::Base
  rescue_from ActiveRecord::RecordNotFound, use: NotFoundError
  rescue_from Net::OpenTimeout, Timeout::Error, use: ServiceUnavailableError
end
```

If `ActiveRecord::RecordNotFound` is raised anywhere in `call`, the caller receives:

```ruby
result.success?       # => false
result.error.message  # => "[ActiveRecord::RecordNotFound]: Couldn't find Account with 'id'=999"
result.error.http_status  # => :not_found
```

### With a block

For more control, provide a block. The block receives the exception and has access to `success` and `failure`:

```ruby
class Treasury::TransferGold::Service < Servus::Base
  rescue_from ActiveRecord::RecordInvalid do |exception|
    failure(
      "Transfer failed: #{exception.record.errors.full_messages.join(', ')}",
      type: ValidationError
    )
  end

end
```

Blocks can return `success` too — this allows recovering from certain exceptions:

```ruby
rescue_from Cache::MissError do |_exception|
  result = fetch_from_database
  success(data: result)
end
```

## Custom error classes

Create domain-specific errors by inheriting from `ServiceError`:

```ruby
class InsufficientFundsError < Servus::Support::Errors::ServiceError
  DEFAULT_MESSAGE = "Insufficient funds"

  def http_status = :unprocessable_entity

  def api_error
    { code: http_status, message: message }
  end
end

# Usage
failure("Account balance too low", type: InsufficientFundsError)
```

## When to use what

| Situation | Use | Why |
| --- | --- | --- |
| Business rule prevents the action | `failure(...)` | Caller can handle it — it's an expected outcome |
| Input violates the schema | Schema validation | Caught before `call` runs — see [Schema Validation](/features/schema-validation) |
| External dependency times out | `rescue_from` | Converts infrastructure exceptions into caller-friendly failures |
| System invariant is broken | `error!()` or let it raise | The application is in a bad state — don't normalize it |
