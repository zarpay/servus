# Service Objects

Every Servus service lives in its own namespaced module with a `Service` class at the root. The module boundary makes the public surface explicit — outside callers only touch `Service.call`. Everything else is internal to the action.

## Directory structure

Each service owns its namespace directory. Service-specific helpers live under `support/` and should never be used outside the service.

```text
app/services/
├── treasury/
│   └── transfer_gold/
│       ├── service.rb
│       └── support/
│           ├── balance_snapshot.rb
│           └── ledger_formatter.rb
└── ravens/
    └── dispatch_message/
        ├── service.rb
        └── support/
            └── payload_builder.rb
```
## Why the namespace matters

**Encapsulation.** The only public interface is `Service.call`. Support classes, private methods, and internal state stay behind the module boundary.

**Naming freedom.** Two services can both have a `Support::Client` or `Support::Validator` without colliding. Simple names stay simple.

**Refactorability.** If nothing inside the namespace leaks, you can rename, move, or delete the entire directory with confidence that nothing else breaks.
## Why support classes should never leak

Support classes are written for their parent service's context. Using them elsewhere creates silent coupling — changes to the support class gain an invisible blast radius across unrelated services.

If multiple services need the same capability, that's usually a sign that a service is missing. Extract the shared work into its own service first — then a concern or `lib/` class if a service doesn't fit.

## Composition

Services can call other services. The safest default is to return a failed downstream response unchanged unless the calling service has a reason to translate it.

```ruby
def call
  reserve = Treasury::ReserveFunds::Service.call(account: @account, amount: @amount)
  return reserve unless reserve.success?

  dispatch = Ravens::DispatchReceipt::Service.call(transfer: reserve.data.transfer_id)
  return dispatch unless dispatch.success?

  success(transfer: reserve.data, receipt: dispatch.data)
end
```

## When to extract a service

Extraction pays off when an action has a business name, more than one meaningful failure mode, or enough orchestration that a dedicated boundary helps the reader. If the code is simply formatting data or mapping one record, a plain Ruby class is simpler.
