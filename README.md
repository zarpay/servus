[![Docs](https://img.shields.io/badge/docs-zarpay.github.io%2Fservus-blue)](https://zarpay.github.io/servus)
[![Gem Version](https://badge.fury.io/rb/servus.svg)](https://badge.fury.io/rb/servus)
[![CI](https://github.com/zarpay/servus/actions/workflows/main.yml/badge.svg)](https://github.com/zarpay/servus/actions/workflows/main.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0-red.svg)](https://www.ruby-lang.org)
[![Rails](https://img.shields.io/badge/activesupport-%3E%3D%208.0-red.svg)](https://rubyonrails.org)

# Servus

A disciplined service-object pattern for Ruby and Rails.

Most mature Rails apps grow a `services/` directory. Servus gives each service the same shape — one entrypoint, one response object, and opt-in layers for validation, guards, events, and async.

## Quick Start

Add to your Gemfile:

```ruby
gem 'servus'
```

```bash
bundle install
```

Generate a service:

```bash
rails g servus:service treasury/transfer_gold from_account to_account gold_dragons
```

Write the service:

```ruby
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

Call it:

```ruby
result = Treasury::TransferGold::Service.call(
  from_account: crown_account,
  to_account: night_watch_account,
  gold_dragons: 50
)

result.success?          # => true
result.data.transferred  # => 50
result.data.from_balance # => 950
result.data.to_balance   # => 550
```

## Documentation

Full documentation at **[zarpay.github.io/servus](https://zarpay.github.io/servus)**

## Features

- **Schema validation** — JSON Schema for arguments, results, and failure data
- **Error handling** — HTTP-aligned error hierarchy with `rescue_from`
- **Guards** — reusable precondition checks with structured errors
- **Events** — decouple follow-up work from the service that triggered it
- **Async execution** — `.call_async` runs the same service through ActiveJob
- **Lazy resolvers** — accept an instance or an ID, resolve on first access
- **Logging** — automatic call, outcome, and duration logging
- **Rails integration** — controller helpers, generators, autoloading via Railtie

## Requirements

- Ruby >= 3.0
- ActiveSupport >= 8.0
- Rails integration is automatic via Railtie; core works in any Ruby application

## License

[MIT](LICENSE)
