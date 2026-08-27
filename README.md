[![Docs](https://img.shields.io/badge/docs-zarpay.github.io%2Fservus-blue)](https://zarpay.github.io/servus)
[![Gem Version](https://badge.fury.io/rb/servus.svg)](https://badge.fury.io/rb/servus)
[![CI](https://github.com/zarpay/servus/actions/workflows/main.yml/badge.svg)](https://github.com/zarpay/servus/actions/workflows/main.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2-red.svg)](https://www.ruby-lang.org)
[![Rails](https://img.shields.io/badge/activesupport-%3E%3D%208.0-red.svg)](https://rubyonrails.org)

# Servus

A disciplined service-object pattern for Ruby and Rails.

Most mature Rails apps grow a `services/` directory. Servus gives each service the same shape — one entrypoint, one response object, and opt-in layers for validation, guards, events, and async.

## Documentation

Full documentation at **[zarpay.github.io/servus](https://zarpay.github.io/servus)**

## Repository layout

This is a monorepo. The gem, its documentation, and a working application that
uses it live together and move together.

```
servus/
├── gem/     the library
├── site/    the documentation
└── demo/    a Rails app that uses every feature
```

| Directory | What it is | How to work on it |
| --- | --- | --- |
| [`gem/`](gem) | The library. Everything published to RubyGems. | `cd gem && bundle exec rake` (specs + RuboCop) |
| [`site/`](site) | VitePress source for the docs published above. | `cd site && npm run dev` |
| [`demo/`](demo) | A Rails app exercising every feature, annotated as a textbook. | `cd demo && bundle exec rspec` |

### Why the demo is in here

`demo/` path-pins the gem source:

```ruby
gem "servus", path: "../gem"
```

so it always runs against the working tree rather than a published version.
That makes it two things at once.

It is **an integration test**. CI runs its suite on every pull request, in a
real Rails application with a database, background jobs, and controllers. A
change to `gem/` that regresses documented behaviour fails there even when the
gem's own unit suite still passes — which has already caught things the unit
suite could not, because some of the gem's sharpest edges only appear once
Rails' autoloading and ActiveJob are involved.

It is also **the reference**. Every public feature has a working example with
commentary explaining why it is written that way and what the alternative
costs. When the docs describe a feature abstractly, the demo shows it running.
[`demo/README.md`](demo/README.md) carries a reading order mapping each feature
to the file that teaches it.

### How the three fit together

A change to a feature usually touches all three: the implementation in `gem/`,
the explanation in `site/`, and a worked example in `demo/`. Keeping them in one
repository means they cannot drift — a docs page describing an API the gem no
longer has is caught by the demo failing to boot, not by a reader.

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

      schema arguments: {
        type: "object",
        required: %w[from_account to_account gold_dragons],
        properties: {
          gold_dragons: { type: "integer", minimum: 1 }
        }
      }

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

## Features

- **Schema validation** — JSON Schema for arguments, results, and failure data
- **Shared schemas** — register reusable fragments once, reference them with `$ref`
- **Error handling** — HTTP-aligned error hierarchy with `rescue_from`
- **Guards** — reusable precondition checks with structured errors
- **Events** — decouple follow-up work from the service that triggered it
- **Async execution** — `.call_async` runs the same service through ActiveJob
- **Lazy resolvers** — accept an instance or an ID, resolve on first access
- **Logging** — automatic call, outcome, and duration logging
- **Rails integration** — controller helpers, generators, autoloading via Railtie

## Requirements

- Ruby >= 3.2
- ActiveSupport >= 8.0

Rails integration is automatic via the Railtie. The core — services, schemas,
guards, and the event bus — works in any Ruby application. Async execution and
event reactions require ActiveJob; lazy resolvers require ActiveRecord.

## License

[MIT](LICENSE)
