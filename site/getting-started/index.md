# Quick Start

## Installation

Add Servus to your Gemfile:

```ruby
gem 'servus'
```

```bash
bundle install
```

Requires Ruby 3.0+ and ActiveSupport 8.0+. Rails integration is automatic via Railtie; Servus core works in any Ruby application, though has more features enabled in Rails.

## Generate a service

Generate the service scaffold with the arguments it will accept:

```bash
rails g servus:service treasury/transfer_gold from_account to_account gold_dragons

=> create app/services/treasury/transfer_gold/service.rb
=> create spec/services/treasury/transfer_gold/service_spec.rb
```

## A basic service

A Servus service inherits from `Servus::Base`, defines `initialize` and `call`, and calls `success(...)` to return a `Response`.

```ruby
# app/services/treasury/transfer_gold/service.rb
module Treasury
  module TransferGold
    class Service < Servus::Base
      def initialize(from_account:, to_account:, gold_dragons:)
        @from_account = from_account
        @to_account = to_account
        @gold_dragons = gold_dragons
      end

      def call
        @from_account.withdraw!(@gold_dragons)
        @to_account.deposit!(@gold_dragons)

        success(
          transferred: @gold_dragons,
          from_balance: @from_account.balance,
          to_balance: @to_account.balance
        )
      end
    end
  end
end
```

Even at a basic level, a few conventions matter:

**One module, one service.** Each service lives in its own namespaced module with a `Service` class at the root. The only public method is `.call` — this treats the service as an internal API with a standard contract for its inputs (arguments) and outputs (response).

**Keyword arguments only.** Always use kwargs in `initialize`, never positional arguments. Error messages become more helpful and callers gain freedom in argument ordering.

**One `Servus::Base` per namespace.** The `Service` class is the only class in the module that inherits from `Servus::Base`. It's where the runtime wraps `call` and provides the functionality covered throughout the docs.

## Calling the service

Every service is called with `.call` and keyword arguments:

```ruby
result = Treasury::TransferGold::Service.call(
  from_account: crown_account,
  to_account: night_watch_account,
  gold_dragons: 50
)
```

Servus automatically logs every call with timing:

```
Calling Treasury::TransferGold::Service with args: {:from_account=>#<Account id: 1>, :to_account=>#<Account id: 2>, :gold_dragons=>50}
Treasury::TransferGold::Service succeeded in 0.013s
```

## Reading the result

Every service returns a `Response` with the same shape — `success?`, `data`, and `error`. Any hash passed to `success(...)` is deeply wrapped in a `DataObject`, so nested values are accessible as methods at any depth.

```ruby
puts result.success?          # => true
puts result.data.transferred  # => 50
puts result.data.from_balance # => 950
puts result.data.to_balance   # => 550
puts result.error             # => nil
```

| Method | Returns |
| --- | --- |
| `result.success?` | `true` or `false` |
| `result.data` | A `DataObject` wrapping the success payload — supports bracket and accessor syntax |
| `result.error` | `nil` on success, a `ServiceError` on failure |

This is Servus at its simplest — but there's much more. Schema validation, guards, events, async execution, lazy resolvers, and declarative error handling all layer onto the same interface. The core stays the same: one class, one `.call`, one response.