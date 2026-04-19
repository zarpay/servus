# Guards

Guards are reusable precondition checks that halt service execution when a condition isn't met. Instead of scattering the same validation logic across many services, you give the check a name, an error contract, and a single place to maintain it.

## The problem guards solve

Without guards, preconditions accumulate as early returns in every service that needs them:

```ruby
def call
  return failure("Sender account must be open")      unless @from_account.open?
  return failure("Receiver account must be open")    unless @to_account.open?
  return failure("Sender account must not be frozen") unless !@from_account.frozen?
  return failure("Receiver account must not be frozen") unless !@to_account.frozen?
  return failure("Insufficient funds")               unless @from_account.balance >= @gold_dragons

  # finally, the actual business logic...
end
```

With a guard, all four checks collapse into one statement:

```ruby
def call
  enforce_eligible_transfer!(
    from: from_account,
    to: to_account,
    amount: @gold_dragons
  )

  from_account.withdraw!(@gold_dragons)
  to_account.deposit!(@gold_dragons)

  success(
    transferred: @gold_dragons,
    from_balance: from_account.balance,
    to_balance: to_account.balance
  )
end
```

The guard reads as a single precondition in domain language. When it fails, it automatically returns a structured failure `Response` with an HTTP status, error code, and human-readable message — no manual wiring needed.

## Creating a guard

Generate the guard:

```bash
rails g servus:guard eligible_transfer

=> create app/guards/eligible_transfer_guard.rb
```

A guard inherits from `Servus::Guard` and defines its behavior with a small DSL:

| Method | Purpose |
| --- | --- |
| `test` | **Required.** Must return `true` (guard passes) or `false` (guard fails). Accepts the same keyword arguments that callers pass to `enforce_*!` |
| `http_status` | HTTP status code returned in the failure response (default: 422) |
| `error_code` | Machine-readable error code for API clients (default: `'validation_failed'`) |
| `message` | Human-readable error message, with optional `%<key>s` interpolation via a block |

The `message` block is evaluated in the guard instance's context, where all kwargs are accessible directly as methods (e.g., `amount` instead of `kwargs[:amount]`).

```ruby
# app/guards/eligible_transfer_guard.rb
class EligibleTransferGuard < Servus::Guard
  http_status 422
  error_code 'ineligible_transfer'

  message 'Transfer ineligible: %<reason>s' do
    { reason: find_reason }
  end

  def test(from:, to:, amount:)
    from.open? &&
    to.open? &&
    !from.frozen? &&
    !to.frozen? &&
    from.balance >= amount
  end

  private

  def find_reason
    from = kwargs[:from]
    to = kwargs[:to]
    amount = kwargs[:amount]

    return "Sender account must be open" unless from.open?
    return "Receiver account must be open" unless to.open?
    return "Sender account is frozen" if from.frozen?
    return "Receiver account is frozen" if to.frozen?
    return "Insufficient funds: need #{amount}, have #{from.balance}" unless from.balance >= amount
  end
end
```

This gives you a single, testable, and reusable guard that can be applied in any service that transfers gold — not just `Treasury::TransferGold`. The guard asserts itself the same way whether the service is called synchronously from an API request or asynchronously from a background job. Write the rule once, test it once, and enforce it everywhere.

## Built-in guards

Servus ships with four basic guards — `PresenceGuard`, `TruthyGuard`, `FalseyGuard`, and `StateGuard`. They're useful as reference implementations for how to build guards, but the real value of the guard system comes from domain-specific guards like `EligibleTransferGuard` above.

| Guard | Method | What it checks |
| --- | --- | --- |
| `PresenceGuard` | `enforce_presence!(user: user)` | Values are not nil or empty |
| `TruthyGuard` | `enforce_truthy!(on: user, check: :active?)` | Attribute is truthy |
| `FalseyGuard` | `enforce_falsey!(on: user, check: :banned?)` | Attribute is falsey |
| `StateGuard` | `enforce_state!(on: order, check: :status, is: :open)` | Attribute matches a value |

## Bang vs predicate

Each guard provides two methods:

```ruby
# Bang (!) — halts execution on failure, returns a failure Response
enforce_eligible_transfer!(
  from: from_account,
  to: to_account,
  amount: @gold_dragons
)

# Predicate (?) — returns a boolean, execution continues
eligible = check_eligible_transfer?(
  from: from_account,
  to: to_account,
  amount: @gold_dragons
)

if eligible
  perform_standard_transfer
else
  perform_manual_review_transfer
end
```

Use bang methods for preconditions that must pass. Use predicate methods for conditional logic where both paths are valid.

## How guards fail

Guards use Ruby's `throw`/`catch` mechanism rather than `raise`/`rescue`. This is a deliberate choice — `throw`/`catch` is roughly 3-4x faster because `raise` has to generate a full stack trace on every exception. Ruby allocates the backtrace array, walks the call stack, and formats each frame into a string. For a precondition check that fires on every service call, that overhead adds up. `throw` skips all of it — it simply unwinds the stack to the nearest `catch` block with no backtrace generation.

When a bang guard fails, it throws `:guard_failure` with a `GuardError`. The framework catches this in the [call chain](/core/call-chain#_4-run-your-call-method) and converts it to a failure `Response` automatically:

```ruby
result = Treasury::TransferGold::Service.call(
  from_account: underfunded_account,
  to_account: night_watch_account,
  gold_dragons: 1000
)

result.success?              # => false
result.error.message         # => "Insufficient balance: need 1000, have 50"
result.error.code            # => "insufficient_balance"
result.error.http_status     # => 422
```

The caller never sees the guard mechanism — they get the same `Response` shape as any other failure.

Guards can be used in any method of the service — `call` or private methods. The `throw` always unwinds to the `catch` block in the call chain regardless of how deep in the call stack the guard fires.

## Naming convention

Guard class names describe the **condition being checked**, not the action. The framework adds `enforce_` and `check_` prefixes automatically:

| Class name | Bang method | Predicate method |
| --- | --- | --- |
| `SufficientBalanceGuard` | `enforce_sufficient_balance!` | `check_sufficient_balance?` |
| `OpenAccountGuard` | `enforce_open_account!` | `check_open_account?` |
| `ActiveMembershipGuard` | `enforce_active_membership!` | `check_active_membership?` |

Don't use action verbs in the class name — `EnforceSufficientBalanceGuard` would generate `enforce_enforce_sufficient_balance!`.

## Configuration

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.include_default_guards = false  # disable built-in guards (default: true)
  config.guards_dir = 'app/guards'       # where custom guards live (default: 'app/guards')
end
```

Custom guards in `app/guards/` are automatically loaded by the Railtie. Files must follow the `*_guard.rb` naming convention.
