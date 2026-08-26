# Composition

Most non-trivial actions need to invoke other actions. In Servus a service
invokes another service exactly the way anything else does — `.call`, check the
result, decide what happens next:

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
        transfer = Treasury::TransferGold::Service.call(
          from_account: @from_account,
          to_account: @to_account,
          gold_dragons: @gold_dragons
        )
        return transfer unless transfer.success?

        receipt = Ravens::DispatchReceipt::Service.call(transfer_id: transfer.data.id)
        return receipt unless receipt.success?

        success(transfer_id: transfer.data.id)
      end
    end
  end
end
```

There is one way to invoke a service and one way to handle what it returns. The
whole control flow is on the page: which calls happen, in what order, and what a
failure does to the rest of the method.

## Passing a failure through

`return result unless result.success?` returns the sub-service's failure
`Response` unchanged — same error object, message, `code`, and `http_status`.
The outer service's caller receives it as though they had invoked the
sub-service directly, so a `NotFoundError` raised three services deep still
reaches the controller as a 404.

That's usually what you want. It's worth writing out, because the alternative is
a reader having to know that some other construct decided it for them.

## Handling a failure instead

When the outer service has something to add — a fallback, a retry, an error
specific to its own domain — branch on the result:

```ruby
def call
  result = Payments::ChargeCard::Service.call(**params)
  return success(charge_id: result.data.id) if result.success?
  return failure('Card declined', type: PaymentDeclinedError) if card_declined?(result.error)

  # Let other failures pass through untouched
  result
end
```

Pass-through and handling share a shape, so moving between them is a one-line
change rather than a switch between two different calling conventions.

## Preconditions belong in guards

Composition is for invoking other services. When you're enforcing a
precondition rather than calling something, reach for a
[guard](/features/guards) instead — guards halt the service without the caller
writing any branching at all.

## Driving a service from outside

Controllers, jobs, rake tasks, and consoles aren't services, so they have no
`#call` to return from. `Servus::Helpers::ControllerHelpers` covers that
boundary:

```ruby
class UsersController < ApplicationController
  def create
    run_service Services::CreateUser::Service, user_params
  end
end
```

`run_service` stores the full `Response` in `@result` so views and downstream
helpers can read it, and renders a JSON error on failure using the error's
`http_status` and `api_error`. Override
[`render_service_error`](/rails/controllers) to change that format.

Anywhere raising suits better than rendering — a webhook handler, a rake task —
call the service directly and raise:

```ruby
result = Payments::RecordWebhook::Service.call(event: event)
raise result.error unless result.success?
```

## One way in

A service has a single public entry point: `.call(**args)`. A controller, a job,
an event router, another service — all invoke it identically and all get back
the same `Response`.

Servus previously shipped two helpers that wrapped that call: `call!` for
composing services and `run_service!` for driving one from a controller
context. Both returned `data` on success and diverted on failure — `call!` by
throwing to halt the outer service, `run_service!` by raising. Both are
**removed in 1.0.0**.

They read like ordinary method calls while hiding a non-local jump, and they
meant the same operation had two calling conventions depending on where you
stood. Writing `.call` and an explicit `return` or `raise` costs a line and
makes the control flow something you can see rather than something you have to
know.
