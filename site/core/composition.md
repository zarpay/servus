# Composition

Most non-trivial actions need to invoke other actions. Servus gives you one helper for composing services — `call!` — and one for driving a service from outside the service layer — `run_service!`. Both eliminate the same boilerplate: checking `success?`, extracting `data`, and early-returning on failure.

## `call!` — inside services

`call!` is the primary composition helper. It is an instance method mixed into every `Servus::Base`, so it's available anywhere your `#call` runs.

```ruby
module Treasury
  module TransferAndNotify
    class Service < Servus::Base
      def initialize(from_account:, to_account:, gold_dragons:)
        @from_account = from_account
        @to_account = to_account
        @gold_dragons = gold_dragons
      end

      def call
        transfer = call!(
          Treasury::TransferGold::Service,
          from_account: @from_account,
          to_account: @to_account,
          gold_dragons: @gold_dragons
        )

        call!(Ravens::DispatchReceipt::Service, transfer_id: transfer.id)

        success(transfer_id: transfer.id)
      end
    end
  end
end
```

On success, `call!` returns the sub-service's data — the same `DataObject` the caller would get from `SubService.call(...).data`. On failure, it halts the outer service and passes the sub-service's failure `Response` through unchanged: same error object, same message, same `code`, same `http_status`. The outer service's caller receives the sub-service's failure as if they had invoked it directly.

### Why `call!` exists

The same code without `call!`:

```ruby
def call
  transfer_result = Treasury::TransferGold::Service.call(
    from_account: @from_account,
    to_account: @to_account,
    gold_dragons: @gold_dragons
  )
  return transfer_result unless transfer_result.success?

  dispatch_result = Ravens::DispatchReceipt::Service.call(
    transfer_id: transfer_result.data.id
  )
  return dispatch_result unless dispatch_result.success?

  success(transfer_id: transfer_result.data.id)
end
```

Every sub-service call grows three lines of plumbing: one to invoke, one to branch, one to early-return. Pull that plumbing out and the business logic is what's left.

### Failure semantics

`call!` uses the same `throw/catch` mechanism as guards. When the sub-service fails, `call!` throws `:guard_failure` with the sub-service's failure `Response`. The `catch` block inside `Servus::Base.call` unwraps it and returns that Response as the outer service's result — see [Call Chain](/core/call-chain#_4-run-your-call-method).

Because the *original* failure flows through, callers don't need to care that the failure came from a sub-service. A `NotFoundError` from `Accounts::Lookup::Service` arrives at the controller as a 404 even when it was raised three services deep.

### When not to use `call!`

Use `call!` when the outer service has no better context to add and any sub-service failure should halt composition. Don't use it when you want to inspect the failure, try a fallback, or translate the error into something more specific to the outer service's domain. In those cases, call the sub-service directly and branch on `result.success?`.

```ruby
def call
  result = Payments::ChargeCard::Service.call(**params)
  return success(charge_id: result.data.id) if result.success?
  return failure('Card declined', type: PaymentDeclinedError) if card_declined?(result.error)

  # Let other failures pass through
  result
end
```

## `run_service!` — outside services

`run_service!` is the bang counterpart to `run_service` on `Servus::Helpers::ControllerHelpers`. It returns the service's data on success and raises the failure's error otherwise. Use it wherever raising is preferable to rendering — background callbacks, rake tasks reachable through a controller context, or any path where a failure is a bug, not a render opportunity.

```ruby
class WebhooksController < ApplicationController
  def stripe
    event = Stripe::Webhook.construct_event(request.body.read, signature, secret)

    # Raises on failure — bubbles to the default exception middleware
    run_service!(Payments::RecordWebhook::Service, event: event)

    head :ok
  end
end
```

### `run_service!` vs `run_service`

| Helper | Lives on | On success | On failure |
| --- | --- | --- | --- |
| `run_service` | `ControllerHelpers` | Sets `@result`, returns `Response` | Renders JSON error, returns `Response` |
| `run_service!` | `ControllerHelpers` | Returns the result's `data` | Raises the failure's `ServiceError` |
| `call!` | `Servus::Base` | Returns the result's `data` | Halts outer service with failure `Response` |

`run_service` is the default for controller actions — it handles the JSON response for you. Reach for `run_service!` only when raising is what you actually want.

## The two public methods

Servus exposes a small surface on purpose. For invocation, there are only two public methods anyone writing a service will ever need:

1. **`.call(**args)`** — the class-level entry point. Every service is invoked through this.
2. **`call!(SubService, **args)`** — the instance-level composition helper. Every sub-service invocation inside `#call` goes through this.

`run_service` / `run_service!` are integration helpers on the controller side, not part of the service's public interface. Keep the service surface to these two and compositions stay uniform across the codebase.
