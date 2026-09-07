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

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.logger = SemanticLogger[Servus]
end
```

Left unset, Servus uses `Rails.logger` when Rails is loaded, otherwise `Logger.new($stdout)`. `Servus.logger` returns whichever applies.

Control the log level through Rails configuration:

```ruby
# config/environments/production.rb
config.log_level = :warn  # Hides info-level call and success logs
```

## Per-service loggers

`Servus::Base.logger` is inherited down the service tree. Assign one to a base class and it covers every service below it:

```ruby
class Treasury::ApplicationService < Servus::Base
  self.logger = SemanticLogger[Treasury]
end
```

Unassigned classes inherit from the class above them, up to `Servus.logger`. Assigning `nil` returns a class to what it inherits.

A host service calling an engine service logs under the host, and the engine service under the engine, in the same call chain — including from a thread the host spawned.

To add to the configured logger rather than replace it, build from `Servus.logger`. `SemanticLogger::Logger#tagged` without a block returns a child logger carrying the tags on every line, keeping the app's appenders, level, and format:

```ruby
self.logger = Servus.logger.tagged(engine: 'treasury')
```

```
INFO [engine: treasury] Treasury::TransferGold::Service succeeded in 0.013s
```

Event emission and schema override lines go to `Servus.logger`. Neither belongs to a service.

## Custom logging inside services

The automatic logging covers the lifecycle — call, outcome, duration. Inside `call`, `logger` is the service class's logger:

```ruby
def call
  logger.info("Transferring #{@gold_dragons} gold dragons from #{from_account.id} to #{to_account.id}")

  from_account.withdraw!(@gold_dragons)
  to_account.deposit!(@gold_dragons)

  success(transferred: @gold_dragons, from_balance: from_account.balance, to_balance: to_account.balance)
end
```

## Sensitive data

Arguments are logged verbatim at `info` level. To keep credentials (tokens, passwords, auth hashes) out of your logs, configure `log_filter_parameters` — matching values are replaced with `[FILTERED]`:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.log_filter_parameters = [
    :passw, :email, :secret, :token, :_key, :crypt, :salt,
    :certificate, :otp, :ssn, :cvv, :cvc
  ]
end
```

```
INFO  Calling Sessions::Resolve::Service with args: {token: "[FILTERED]"}
```

The option accepts the same notations as `ActiveSupport::ParameterFilter`: partial-match strings/symbols, regexps, and procs. It defaults to `[]` — no filtering — so it's entirely opt-in, and it works in any Ruby app, not just Rails.

Rails users can simply reuse their app's request-log filtering as the value, so Servus's argument logging matches it exactly (Rails' `filter_parameters` only applies to Servus logs if you assign it here — it isn't picked up automatically):

```ruby
config.log_filter_parameters = Rails.application.config.filter_parameters
```

Rails loads initializers alphabetically, so `config/initializers/filter_parameter_logging.rb` runs before `servus.rb` — any `filter_parameters += [...]` additions are included.

Other options for production:

1. Set the log level to `:warn` to suppress argument logging entirely
2. Pass IDs instead of full objects: `Service.call(user_id: 1)` not `Service.call(user: user_object)`
