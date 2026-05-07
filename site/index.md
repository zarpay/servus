---
layout: home
hero:
  name: Servus
  text: A disciplined service-object pattern for Ruby and Rails
  tagline: Most mature Rails apps grow a services/ directory. Servus gives each service the same shape — one entrypoint, one response object, and opt-in layers for validation, guards, events, and async.
  actions:
    - theme: brand
      text: Start with Quick Start
      link: /getting-started/
    - theme: alt
      text: Explore Core Concepts
      link: /core/service-objects
---

## What a service looks like

A Servus service is a Ruby class that inherits from `Servus::Base`, defines `initialize` and `call`, and returns a `Response`.

```ruby
module Treasury
  module TransferGold
    class Service < Servus::Base
      # Validate arguments before call, results after
      schema(
        arguments: {
          type: "object",
          required: ["from_account", "to_account", "gold_dragons"],
          properties: {
            from_account: { type: ["integer", "object"] },
            to_account: { type: ["integer", "object"] },
            gold_dragons: { type: "integer", minimum: 1 }
          }
        },
        result: {
          type: "object",
          required: ["transferred", "from_balance", "to_balance"],
          properties: {
            transferred: { type: "number" },
            from_balance: { type: "number" },
            to_balance: { type: "number" }
          }
        }
      )

      # Fire an event for Event classes to pick up
      emits :gold_transferred, on: :success

      # Accept an Account instance or an ID — resolve lazily
      lazily :from_account, finds: Account
      lazily :to_account, finds: Account

      def initialize(from_account:, to_account:, gold_dragons:)
        @from_account = from_account
        @to_account = to_account
        @gold_dragons = gold_dragons
      end

      def call
        # Business failure — returns a Response the caller can handle
        return failure("Cannot transfer to the same account") if transferring_to_self?

        # Guard — halts with a structured error if the precondition fails
        enforce_eligible_transfer!(
          from: from_account,
          to: to_account,
          amount: @gold_dragons
        )

        from_account.withdraw!(@gold_dragons)
        to_account.deposit!(@gold_dragons)

        # Success — wrapped in a DataObject with accessor methods
        success(
          transferred: @gold_dragons,
          from_balance: from_account.balance,
          to_balance: to_account.balance
        )
      end

      private

      def transferring_to_self?
        from_account == to_account
      end
    end
  end
end
```

## What's happening here

There's a lot on that page — here's what each piece does, with links to the relevant docs.

| Piece | What it does | Docs |
| --- | --- | --- |
| `< Servus::Base` | The base class. Wraps your `call` method with validation, logging, event dispatch, and error handling. | [Service Objects](/core/service-objects) |
| `lazily :from_account, finds: Account` | The argument accepts an `Account` instance or an id; the service resolves whichever is passed. | [Lazy Resolvers](/features/lazy-resolvers) |
| `schema(arguments:, result:)` | Optional JSON Schema validation for arguments (before `call`) and results (after). Here it rejects decimals and amounts below 1. | [Schema Validation](/features/schema-validation) |
| `emits :gold_transferred, on: :success` | Fires an event on successful completion for Event classes to pick up. | [Event Bus](/features/event-bus) |
| `enforce_eligible_transfer!(...)` | A guard. Halts execution and returns a structured failure if the precondition isn't met. | [Guards](/features/guards) |
| `failure(...)` and `success(...)` | The two ways a service returns. Both produce a `Response` the caller can branch on. | [Responses](/core/responses) |

Callers get a single, predictable shape:

```ruby
result = Treasury::TransferGold::Service.call(from_account: 1, to_account: 2, gold_dragons: 50)

puts result.success?          # => true
puts result.data.transferred  # => 50
puts result.data.from_balance # => 950
puts result.data.to_balance   # => 550

# Business failure
result = Treasury::TransferGold::Service.call(from_account: 1, to_account: 1, gold_dragons: 50)

puts result.success?       # => false
puts result.error.message  # => "Cannot transfer to the same account"
```

The same service runs inline through `.call` or through ActiveJob via [`.call_async`](/features/async-execution).

## How to read this

The handbook moves outward from the basics:

- **Getting Started** — a minimum service and the mental model behind it
- **Core Concepts** — services, the call chain, responses, architecture
- **Features** — schema validation, error handling, guards, events, async, lazy resolvers
- **Rails Integration** — controllers, generators, configuration, background jobs
- **Testing** — framework testing and the RSpec matchers
- **Reference** — generators and dry-initializer

## The running example

Most examples come from RavenPay, a fictional treasury and messaging system. Using one running example keeps the vocabulary consistent across services, events, guards, and async work.
