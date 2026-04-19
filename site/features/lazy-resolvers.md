# Lazy Resolvers

Services often accept record IDs as arguments — especially for [async execution](/features/async-execution), where ActiveJob needs serializable values. But when calling synchronously, the caller may already have the loaded record, and re-querying the record in the service is wasteful.

`lazily` solves this. The service accepts either an instance or an ID through the same parameter. Resolution only happens when the accessor is first called, and only if the value isn't already an instance.

## Basic usage

```ruby
class Treasury::TransferGold::Service < Servus::Base
  lazily :from_account, finds: Account
  lazily :to_account, finds: Account

  def initialize(from_account:, to_account:, gold_dragons:)
    @from_account = from_account
    @to_account = to_account
    @gold_dragons = gold_dragons
  end

  def call
    from_account.withdraw!(@gold_dragons)
    to_account.deposit!(@gold_dragons)

    success(
      transferred: @gold_dragons,
      from_balance: from_account.balance,
      to_balance: to_account.balance
    )
  end
end
```

Callers pass whatever they have:

```ruby
# Sync — pass loaded records, no query
Treasury::TransferGold::Service.call(
  from_account: current_account,
  to_account: recipient_account,
  gold_dragons: 50
)

# Async — pass IDs, resolved by the worker
Treasury::TransferGold::Service.call_async(
  from_account: current_account.id,
  to_account: recipient_account.id,
  gold_dragons: 50
)

# Sync with IDs — also works
Treasury::TransferGold::Service.call(
  from_account: 1,
  to_account: 2,
  gold_dragons: 50
)
```

The service code is identical in all three cases. The resolver handles the difference.

## DSL

```ruby
lazily :name, finds: ModelClass              # resolves via ModelClass.find(value)
lazily :name, finds: ModelClass, by: :column # resolves via ModelClass.find_by!(column: value)
```

| Parameter | Description |
| --- | --- |
| `:name` | Must match the instance variable name set in `initialize` (e.g., `lazily :from_account` reads from `@from_account`) |
| `finds:` | The model class (e.g., `Account`, `User`) |
| `by:` | Lookup column. Defaults to `:id`. When set, uses `.find_by!` instead of `.find` |

## Resolution behavior

The resolver checks the input type and acts accordingly:

### Instance — no query

```ruby
account = Account.find(1)
Treasury::TransferGold::Service.call(
  from_account: account,
  to_account: other,
  gold_dragons: 50
)

# from_account returns the same object — no SQL executed
```

### Scalar (Integer, String) — resolves via `.find` or `.find_by!`

```ruby
Treasury::TransferGold::Service.call(
  from_account: 1,
  to_account: 2,
  gold_dragons: 50
)

# First call to from_account runs:
#   Account.find(1)
#   => #<Account id: 1, balance: 1000>
```

With `by:` set to a custom column:

```ruby
lazily :account, finds: Account, by: :uuid

# Resolves via:
#   Account.find_by!(uuid: "abc-def-123")
```

### Array — resolves via `.where`

```ruby
lazily :recipients, finds: Account

BulkTransfer::Service.call(
  recipients: [1, 2, 3],
  gold_dragons: 50
)

# First call to recipients runs:
#   Account.where(id: [1, 2, 3])
#   => #<ActiveRecord::Relation [#<Account id: 1>, #<Account id: 2>, #<Account id: 3>]>
```

Arrays respect the `by:` column:

```ruby
lazily :recipients, finds: Account, by: :uuid

BulkTransfer::Service.call(
  recipients: ["abc-123", "def-456", "ghi-789"],
  gold_dragons: 50
)

# First call to recipients runs:
#   Account.where(uuid: ["abc-123", "def-456", "ghi-789"])
```

Empty arrays return an empty relation — no error is raised. This is intentional for batch operations where an empty set is valid.

### Nil — raises immediately

```ruby
Treasury::TransferGold::Service.call(
  from_account: nil,
  to_account: 2,
  gold_dragons: 50
)

# => raises Servus::Extensions::Lazily::Errors::NotFoundError
#    "Couldn't find Account (from_account was nil)"
```

### Lazy and memoized

Resolution only happens when the accessor is first called inside `call`, not during `initialize`. If the service never calls the accessor, no query is made. Once resolved, the record is written back to the instance variable — subsequent calls return the same object without re-querying.

## Custom column lookup

Use `by:` to look up by a column other than `:id`:

```ruby
lazily :account, finds: Account, by: :uuid

# Resolves via Account.find_by!(uuid: "abc-def-123")
Treasury::TransferGold::Service.call(account: "abc-def-123")

# Passes through an Account instance directly
Treasury::TransferGold::Service.call(account: loaded_account)
```

## Multiple resolvers

A service can declare multiple resolvers. Each resolves independently and memoizes separately:

```ruby
lazily :from_account, finds: Account
lazily :to_account, finds: Account
lazily :approver, finds: User, by: :email
```

## Error handling

### Nil input

Raises `Servus::Extensions::Lazily::Errors::NotFoundError` immediately with a message including the param name and target class:

```
Couldn't find Account (from_account was nil)
```

### Missing record

`.find` and `.find_by!` raise `ActiveRecord::RecordNotFound` as usual. Use `rescue_from` to convert these to failure responses:

```ruby
class Service < Servus::Base
  lazily :from_account, finds: Account
  rescue_from ActiveRecord::RecordNotFound, use: NotFoundError
end
```

### Empty array

Returns an empty ActiveRecord relation — no error. This is intentional for batch operations where an empty set is valid.

## Why this matters

Without `lazily`, you either accept an ID (and always query, even when the caller had the record) or accept an instance (and break async execution, which needs serializable arguments). Teams end up writing the resolution boilerplate in every service, or splitting sync and async paths.

`lazily` eliminates that choice. One parameter, one service, both paths. The service is indifferent to how it's called — which is the same principle behind `.call` and `.call_async` sharing the same lifecycle.

### Built-in memoization

`lazily` also replaces the common memoization pattern. Without it, services that look up records tend to accumulate `||=` calls:

```ruby
def call
  from_account.withdraw!(@gold_dragons)
  to_account.deposit!(@gold_dragons)

  success(transferred: @gold_dragons)
end

private

def from_account
  @from_account ||= Account.find(@from_account_id)
end

def to_account
  @to_account ||= Account.find(@to_account_id)
end
```

With `lazily`, this disappears. The resolver handles lookup, type checking, and memoization in one declaration. Every call to `from_account` returns the same resolved object — no `||=`, no local variables, no manual caching.

::: info ActiveRecord only
`lazily` is an ActiveRecord extension. It loads automatically via Railtie when ActiveRecord is present. It is not available in pure Ruby applications without ActiveRecord.
:::
