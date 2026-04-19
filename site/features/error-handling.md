# Error Handling

Servus draws an important line between expected business failures and unexpected system exceptions. The cleaner you preserve that line, the more readable your services remain.

## Failures versus exceptions

| Situation | Recommended approach | RavenPay example |
| --- | --- | --- |
| Business rule prevents the action | `failure(...)` | The source treasury account lacks funds |
| Input is invalid | Schema validation or `failure(...)` | The requested transfer amount is negative |
| System invariant is broken | Raise or let a bang method raise | The referenced ledger account does not exist |
| External dependency fails | `rescue_from` or exception mapping | The rookery gateway times out |

## Expected failure

```ruby
def call
  return failure('Only wartime couriers may use urgent dispatch') if urgent? && !courier.wartime_clearance?

  success(dispatch: create_dispatch!)
end
```

## Declarative exception handling

```ruby
class Ravens::DispatchMessage::Service < Servus::Base
  rescue_from Net::OpenTimeout, Timeout::Error,
    use: Servus::Support::Errors::ServiceUnavailableError

  rescue_from ActiveRecord::RecordInvalid do |exception|
    failure("Dispatch invalid: #{exception.message}", type: Servus::Support::Errors::ValidationError)
  end
end
```

## Guidance

Use `failure` when the domain expects the condition and a caller can handle it intelligently. Raise when the application is broken, misconfigured, or has violated an invariant that should not be normalized away.
