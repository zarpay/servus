# @title Features / 2. Error Handling

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

### Custom Error Handling with Blocks

For more control over error handling, provide a block to `rescue_from`. The block receives the exception and can return either success or failure:

```ruby
class ProcessPayment::Service < Servus::Base
  # Custom failure with error details
  rescue_from ActiveRecord::RecordInvalid do |exception|
    failure("Payment failed: #{exception.record.errors.full_messages.join(', ')}",
            type: ValidationError)
  end

  # Recover from certain errors with success
  rescue_from Stripe::CardError do |exception|
    if exception.code == 'card_declined'
      failure("Card was declined", type: BadRequestError)
    else
      # Log and continue for other card errors
      Rails.logger.warn("Stripe error: #{exception.message}")
      success(recovered: true, fallback_used: true)
    end
  end

  def call
    # Service logic that may raise exceptions
  end
end
```

The block has access to `success(data)` and `failure(message, type:)` methods. This allows conditional error handling and even recovering from exceptions.

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
