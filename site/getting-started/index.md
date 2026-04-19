# Quick Start

Servus is most useful when a business action needs a real boundary. Instead of letting a workflow dissolve into controller code, callbacks, and incidental helpers, you give the action a name, a class, and a consistent way to report what happened.

Quick Start begins with the simplest possible shape. One service owns one action. The caller uses `.call`. The result comes back in a standard form. Everything else in the handbook builds from that foundation.

## A first service

The example below is intentionally small. It performs one action, returns clear failures for ordinary business conditions, and emits an event when the transfer succeeds.

```ruby
module Treasury
  module TransferGold
    class Service < Servus::Base
      emits :gold_transferred, on: :success

      def initialize(from_account:, to_account:, gold_dragons:)
        @from_account = from_account
        @to_account = to_account
        @gold_dragons = gold_dragons
      end

      def call
        return failure('Amount must be positive') unless @gold_dragons.positive?
        return failure('Insufficient funds') if @from_account.balance < @gold_dragons

        @from_account.withdraw!(@gold_dragons)
        @to_account.deposit!(@gold_dragons)

        success(
          transfer: {
            from: @from_account.ledger_id,
            to: @to_account.ledger_id,
            amount: @gold_dragons
          }
        )
      end
    end
  end
end
```

This service is easy to scan because the business action is explicit. It transfers gold from one account to another, rejects invalid input, and returns a structured success payload when the work is complete.

## Calling the service

The normal entrypoint is the class method `.call`.

```ruby
result = Treasury::TransferGold::Service.call(
  from_account: crown_account,
  to_account: night_watch_account,
  gold_dragons: 50
)
```

That call gives the action a stable public boundary. The caller does not need to know how the service is wired internally. It only needs to know which action it is running and how to inspect the result.

## Reading the result

Servus returns a response object, so callers handle outcomes in a consistent way.

```ruby
if result.success?
  puts result.data[:transfer][:amount]
else
  warn result.error.message
end
```

| Question | What to check |
| --- | --- |
| Did the action succeed? | `result.success?` |
| What data came back? | `result.data` |
| Why did it fail? | `result.error.message` |

## Why this pattern helps

A named service makes business work easier to reason about. The action lives in one place. The outcome is predictable. The same calling style can be reused across controllers, jobs, and other services.

| Without a service | With Servus |
| --- | --- |
| The workflow is spread across several layers | The action lives in one named class |
| Success and failure are reported inconsistently | The response follows one standard shape |
| Similar operations drift into different styles | The codebase develops a shared rhythm |

## The first habits that matter

The early habits are straightforward. Name the service after a real action. Keep the `call` method centered on the decision being made. Return clear failures for expected business conditions. Let callers use `.call` and inspect the response.

| Habit | Why it matters |
| --- | --- |
| Name the service after the action | The intent is visible before the implementation is read |
| Keep `call` at the center | The business decision stays easy to find |
| Use `.call` from the outside | Every caller uses the same entrypoint |
| Test success and failure early | The contract becomes reliable from the start |

## What to read next

The next step is **The Servus Mental Model**, followed by **Core Overview**. Those pages explain how the runtime model fits together and how services scale into a larger application design.
