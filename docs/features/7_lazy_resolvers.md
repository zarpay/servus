# @title Features / 7. Lazy Resolvers

# Lazy Resolvers

Services often accept record IDs as inputs and query for the record inside `call`. This is necessary for async execution — ActiveJob serializes arguments, so you can't pass ActiveRecord objects through a job. But when calling synchronously with an already-loaded record, re-querying is wasteful.

The `lazily` DSL solves this. A service declares what records it needs, and the resolver handles both cases transparently: pass an ID and it queries; pass an instance and it skips the query.

## The Problem

Without `lazily`, you write this pattern repeatedly:

```ruby
class ProcessPayment::Service < Servus::Base
  def initialize(user_id:, amount:)
    @user_id = user_id
    @amount = amount
  end

  def call
    user = User.find(@user_id)  # Always queries, even if caller had the record
    # ...
  end
end
```

The caller can't pass a loaded record — `user_id:` expects an integer. And if you change the param to `user:`, it breaks async execution.

## Basic Usage

```ruby
class ProcessPayment::Service < Servus::Base
  lazily :user, finds: User

  def initialize(user:, amount:)
    @user = user
    @amount = amount
  end

  def call
    return failure("Insufficient funds") unless user.balance >= @amount

    user.update!(balance: user.balance - @amount)
    success(user: user, new_balance: user.balance)
  end
end
```

The param is named `user:` — callers pass whatever they have:

```ruby
# Sync with a loaded record — no query
ProcessPayment::Service.call(user: current_user, amount: 50)

# Async with an ID — resolves via User.find(123)
ProcessPayment::Service.call_async(user: user.id, amount: 50)

# Sync with an ID — also works
ProcessPayment::Service.call(user: 123, amount: 50)
```

## DSL Signature

```ruby
lazily :name, finds: ModelClass              # default: ModelClass.find(value)
lazily :name, finds: ModelClass, by: :column # ModelClass.find_by!(column: value)
```

| Parameter | Description |
|-----------|-------------|
| `:name` | The keyword argument name and the accessor method name |
| `finds:` | The model class constant (e.g., `User`, `Account`) |
| `by:` | Lookup column. Defaults to `:id`. When set, uses `.find_by!` instead of `.find` |

## Resolution Behavior

The resolver checks the input type and acts accordingly:

| Input | Behavior |
|-------|----------|
| Instance of target class | Returned directly — no query |
| Integer, String, or other scalar | Resolved via `.find(value)` or `.find_by!(column: value)` |
| Array | Resolved via `.where(column => values)` |
| `nil` | Raises `NotFoundError` immediately |

Resolution is **lazy** — it only happens when the accessor method is first called inside `call`, not during `initialize`. If a service never calls the accessor, no query is made.

Resolution is **memoized** — the resolved record is written back to the instance variable. Subsequent calls return the same object without re-querying.

## Custom Column Lookup

Use `by:` to look up by a column other than `:id`:

```ruby
class FindAccount::Service < Servus::Base
  lazily :account, finds: Account, by: :uuid

  def initialize(account:)
    @account = account
  end

  def call
    success(account: account)
  end
end

# Resolves via Account.find_by!(uuid: "abc-def-123")
FindAccount::Service.call(account: "abc-def-123")

# Passes through an Account instance directly
FindAccount::Service.call(account: loaded_account)
```

The `by:` column accepts any value type — strings, integers, UUIDs — whatever the column expects.

## Array Input

When the input is an Array, the resolver uses `.where` instead of `.find`:

```ruby
class BulkNotify::Service < Servus::Base
  lazily :users, finds: User

  def initialize(users:, message:)
    @users = users
    @message = message
  end

  def call
    users.each { |u| notify(u, @message) }
    success(notified: users.count)
  end
end

# Resolves via User.where(id: [1, 2, 3])
BulkNotify::Service.call(users: [1, 2, 3], message: "Hello")
```

Arrays with a custom `by:` column use `.where(column => values)`.

Empty arrays return an empty relation — no error is raised.

## Multiple Resolvers

A service can declare multiple resolvers. Each resolves independently and memoizes separately:

```ruby
class TransferFunds::Service < Servus::Base
  lazily :sender, finds: User
  lazily :receiver, finds: User
  lazily :account, finds: Account, by: :uuid

  def initialize(sender:, receiver:, account:, amount:)
    @sender = sender
    @receiver = receiver
    @account = account
    @amount = amount
  end

  def call
    # Each resolver triggers independently on first access
    success(from: sender.name, to: receiver.name, account: account.uuid)
  end
end
```

## Error States

### Nil Input

Raises `Servus::Extensions::Lazily::Errors::NotFoundError` immediately. The error message includes the param name and target class:

```
Couldn't find User (user was nil)
```

This is always a bug at the call site — the resolver never silently returns nil.

### Missing Record

`.find` and `.find_by!` raise `ActiveRecord::RecordNotFound` as usual. The resolver does not catch or wrap these errors — they propagate normally.

```ruby
# Raises ActiveRecord::RecordNotFound: Couldn't find User with 'id'=999
ProcessPayment::Service.call(user: 999, amount: 50)
```

Use `rescue_from` if you want to convert these to failure responses:

```ruby
class ProcessPayment::Service < Servus::Base
  lazily :user, finds: User
  rescue_from ActiveRecord::RecordNotFound, use: NotFoundError

  # ...
end
```

### Empty Array

Returns an empty ActiveRecord relation. No error is raised — this is intentional for batch operations where an empty set is valid.

## Async Compatibility

The `lazily` pattern is designed for services that run both synchronously and asynchronously:

```ruby
# Controller (sync) — pass the loaded record
def create
  run_service(ProcessPayment::Service, user: current_user, amount: params[:amount])
end

# Background job (async) — pass the ID
ProcessPayment::Service.call_async(user: user.id, amount: 50)
```

Both paths use the same service code. The resolver handles the difference.

## dry-initializer Compatibility

`lazily` works alongside dry-initializer. The resolver defines its accessor on a prepended module, which takes priority over dry-initializer's generated method. It reads from the `@name` instance variable that dry-initializer sets:

```ruby
class ProcessPayment::Service < Servus::Base
  option :user
  option :amount

  lazily :user, finds: User

  def call
    success(user: user, charged: amount)
  end
end
```

## Requirements

`lazily` is an ActiveRecord extension. It loads automatically via Railtie when ActiveRecord is present in your application. It is not available in pure Ruby applications without ActiveRecord.
