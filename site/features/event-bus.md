# Event Bus

Servus includes an event system so services can trigger follow-up work without absorbing every downstream concern into the original `call` method. That is especially useful when one successful business action should cause several reactions.

## Service-side emission

```ruby
class Treasury::TransferGold::Service < Servus::Base
  emits :gold_transferred, on: :success

  def call
    transfer = perform_transfer!
    success(transfer: transfer)
  end
end
```

## Handler-side reaction

```ruby
class GoldTransferredHandler < Servus::EventHandler
  handles :gold_transferred

  invoke Ravens::DispatchReceipt::Service do |payload|
    {
      transfer_id: payload[:transfer][:id],
      destination: payload[:transfer][:recipient]
    }
  end
end
```

## Why this helps

| Benefit | Result |
| --- | --- |
| Decoupling | The service can stay focused on its main action |
| Reuse | Multiple handlers can react to the same event |
| Observability | Important transitions become explicit |

## Best-practice reading rule

The service should still own the action it is named after. If the service begins coordinating many unrelated reactions directly, it may be a sign that the event system should take over more of that fan-out work.
