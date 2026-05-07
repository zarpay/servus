# Logging

Servus automatically logs every service call with its arguments, outcome, and duration. No instrumentation code needed in your services.

## What gets logged

Every call produces two log lines — one when it starts, one when it finishes:

### Successful call

```
INFO  Calling Treasury::TransferGold::Service with args: {:from_account=>1, :to_account=>2, :gold_dragons=>50}
INFO  Treasury::TransferGold::Service succeeded in 0.013s
```

### Business failure

```
INFO  Calling Treasury::TransferGold::Service with args: {:from_account=>1, :to_account=>1, :gold_dragons=>50}
WARN  Treasury::TransferGold::Service failed in 0.008s with error: Cannot transfer to the same account
```

### Validation error

```
ERROR Treasury::TransferGold::Service validation error: "fifty" is not of type integer
```

### Guard failure

```
WARN  Treasury::TransferGold::Service guard failed: Account must not be frozen
```

### Event emission

```
INFO  Event :gold_transferred_event emitted with payload: {:transferred=>50, :from_balance=>950, :to_balance=>550}
```

### Uncaught exception

```
ERROR Treasury::TransferGold::Service uncaught exception: ActiveRecord::RecordNotFound - Couldn't find Account with 'id'=999
```

## Log levels

| Outcome | Level | When |
| --- | --- | --- |
| Call started | `info` | Every call, with arguments |
| Success | `info` | Call completed successfully, with duration |
| Business failure | `warn` | `failure(...)` returned, with error and duration |
| Guard failure | `warn` | Guard threw `:guard_failure`, with error message |
| Event emission | `info` | Event emitted via `emits` DSL, with payload |
| Validation error | `error` | Schema validation failed (arguments or result) |
| Uncaught exception | `error` | Exception raised and not handled by `rescue_from` |

## Logger configuration

Servus uses `Rails.logger` when available, otherwise `Logger.new($stdout)`. Control the log level through Rails configuration:

```ruby
# config/environments/production.rb
config.log_level = :warn  # Hides info-level call and success logs
```

## Custom logging inside services

The automatic logging covers the lifecycle — call, outcome, duration. If you need to log something specific inside your `call` method, use `Rails.logger` (or whatever logger your app uses) as you normally would. Servus doesn't replace or wrap your application's logger.

```ruby
def call
  Rails.logger.info("Transferring #{@gold_dragons} gold dragons from #{from_account.id} to #{to_account.id}")

  from_account.withdraw!(@gold_dragons)
  to_account.deposit!(@gold_dragons)

  success(transferred: @gold_dragons, from_balance: from_account.balance, to_balance: to_account.balance)
end
```

## Sensitive data

Arguments are logged at `info` level. In production, either:

1. Set the log level to `:warn` to suppress argument logging entirely
2. Use Rails parameter filtering: `config.filter_parameters += [:password, :ssn]`
3. Pass IDs instead of full objects: `Service.call(user_id: 1)` not `Service.call(user: user_object)`
