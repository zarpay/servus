# Autoloading

Servus relies on Rails autoloading for services and uses its Railtie to eager-load guards and Event classes. No manual `require` statements needed.

## Services

Services follow standard Rails autoloading — the file path maps to the constant:

```
app/services/treasury/transfer_gold/service.rb  →  Treasury::TransferGold::Service
app/services/ravens/dispatch_message/service.rb  →  Ravens::DispatchMessage::Service
```

Support classes inside the namespace also autoload:

```
app/services/treasury/transfer_gold/support/balance_snapshot.rb  →  Treasury::TransferGold::Support::BalanceSnapshot
```

## Guards

The Railtie eager-loads all `*_guard.rb` files from the configured `guards_dir` (default: `app/guards`) on every request in development and once at boot in production:

```
app/guards/eligible_transfer_guard.rb  →  EligibleTransferGuard
app/guards/sufficient_balance_guard.rb →  SufficientBalanceGuard
```

Guards must follow the `*_guard.rb` naming convention to be discovered.

## Event classes

The Railtie eager-loads all `*_event.rb` files from the configured `events_dir` (default: `app/events`). In development, the event bus is cleared before reloading to prevent duplicate registrations. After loading, the Railtie calls `ensure_registered!` on each Event subclass to infer event names from classes that didn't set one explicitly:

```
app/events/gold_transferred_event.rb  →  GoldTransferredEvent  (event name: :gold_transferred_event)
app/events/message_dispatched_event.rb →  MessageDispatchedEvent (event name: :message_dispatched_event)
```

## Railtie extensions

The Railtie also wires up additional features when their dependencies are available:

| Extension | Loads when | What it adds |
| --- | --- | --- |
| Controller helpers | `ActionController` loads | `run_service` and `render_service_error` on all controllers |
| Async execution | `ActiveJob` loads | `.call_async` on all services, and event `enqueue` declarations |
| Lazy resolvers | `ActiveRecord` loads | `lazily` DSL on all services |

These are loaded via `ActiveSupport.on_load`, so they only activate when the corresponding Rails component is present.

::: warning Events depend on ActiveJob
Since 1.0.0, event invocation always enqueues, so an Event class that declares `enqueue` needs ActiveJob. Without it, emitting the event raises `Servus::Events::Errors::AsyncBackendMissingError`. Servus's core — services, schemas, guards, and the bus itself — works without ActiveJob; only `enqueue` declarations require it.
:::
