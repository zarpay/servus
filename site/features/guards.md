# Guards

Guards encapsulate reusable validation logic. They help service authors avoid rewriting the same precondition checks in many different services.

## Why guards exist

When the same rule appears in multiple services, duplication makes failures harder to maintain and harder to reason about. A guard gives that rule a name and a reusable error contract.

## Built-in pattern

| Guard style | Use |
| --- | --- |
| Presence-style checks | Ensure required values exist |
| Truthy or falsey checks | Express a simple domain state requirement |
| State checks | Ensure a record is in an allowed state |
| Custom guards | Capture domain-specific policies |

## Custom guard example

```ruby
class OpenAccountGuard < Servus::Guard
  http_status 422
  error_code 'account_not_open'

  message 'Treasury account must be open'

  def test(account:)
    account.open?
  end
end
```

## Using a guard in a service

```ruby
def call
  enforce_open_account!(account: @from_account)
  enforce_open_account!(account: @to_account)

  success(transfer: perform_transfer!)
end
```

## Why guards scale well

Guards separate reusable policy from the body of a service without hiding the policy completely. The service still reads clearly because the guard method names express the preconditions in domain language.
