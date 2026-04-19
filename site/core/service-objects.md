# Service Objects

The service object is the unit around which Servus is built. Every service should communicate one business action clearly through its name, its directory location, and its `call` method.

## Directory structure

The recommended structure is intentionally narrow. Each service lives in its own namespace and keeps service-specific helpers under a `support/` directory that should not leak into wider application use.

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

## Structural rules

| Rule | Reason |
| --- | --- |
| Main service class inherits from `Servus::Base` | The framework lifecycle stays available |
| Service-specific helpers stay under `support/` | Boundaries remain visible |
| The `call` method is the public execution point | Callers know where behavior lives |
| Supporting classes do not need to inherit from `Servus::Base` | The framework should wrap actions, not every helper |

## Composition

Services often call other services. When they do, the safest default is to return a failed downstream response unchanged unless the calling service has a good reason to translate it.

```ruby
def call
  reserve = Treasury::ReserveFunds::Service.call(account: @account, amount: @amount)
  return reserve unless reserve.success?

  dispatch = Ravens::DispatchReceipt::Service.call(transfer_id: reserve.data[:transfer_id])
  return dispatch unless dispatch.success?

  success(transfer: reserve.data, receipt: dispatch.data)
end
```

## When to extract a service

Extraction usually pays off when an action has a business name, more than one meaningful failure mode, or enough orchestration that the reader would benefit from a dedicated boundary. If the code is simply formatting data or mapping one record into another, a service may be unnecessary.
