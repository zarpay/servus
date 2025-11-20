# Error Handling

Servus distinguishes between expected business failures (return failure) and unexpected system errors (raise exceptions). This separation makes error handling predictable and explicit.

## Failures vs Exceptions

**Use `failure()`** for expected business conditions:
- User not found
- Insufficient balance
- Invalid state transition

**Use `error!()` or raise** for unexpected system errors:
- Database connection failure
- Nil reference error
- External API timeout

Failures return a Response object so callers can handle them. Exceptions halt execution and bubble up.

```ruby
def call
  user = User.find_by(id: user_id)
  return failure("User not found", type: NotFoundError) unless user
  return failure("Insufficient funds") unless user.balance >= amount

  user.update!(balance: user.balance - amount)  # Raises on system error
  success(user: user)
end
```

## Error Classes

All error classes inherit from `ServiceError` and map to HTTP status codes. Use them for API-friendly errors.

```ruby
# Built-in errors
NotFoundError          # 404
BadRequestError        # 400
UnauthorizedError      # 401
ForbiddenError         # 403
ValidationError        # 422
InternalServerError    # 500
ServiceUnavailableError # 503

# Usage
failure("Resource not found", type: NotFoundError)
error!("Database corrupted", type: InternalServerError)  # Raises exception
```

Each error has an `api_error` method returning `{ code: :symbol, message: "string" }` for JSON APIs.

## Declarative Exception Handling

Use `rescue_from` to convert specific exceptions into failures. Original exception details are preserved in error messages.

```ruby
class CallExternalApi::Service < Servus::Base
  rescue_from Net::HTTPError, Timeout::Error use: ServiceUnavailableError
  rescue_from JSON::ParserError, use: BadRequestError

  def call
    response = http_client.get(url)  # May raise
    data = JSON.parse(response.body) # May raise
    success(data: data)
  end
end

# If Net::HTTPError is raised, service returns:
# Response(success: false, error: ServiceUnavailableError("[Net::HTTPError]: original message"))
```

The `rescue_from` pattern keeps business logic clean while ensuring consistent error handling across services.

## Custom Errors

Create domain-specific errors by inheriting from `ServiceError`:

```ruby
class InsufficientFundsError < Servus::Support::Errors::ServiceError
  DEFAULT_MESSAGE = "Insufficient funds"

  def api_error
    { code: :insufficient_funds, message: message }
  end
end

# Usage
failure("Account balance too low", type: InsufficientFundsError)
```
