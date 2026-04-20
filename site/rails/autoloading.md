# Autoloading

Servus relies on Rails autoloading for services and uses its Railtie to eager-load guards and event handlers. No manual `require` statements needed.

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

## Event handlers

The Railtie eager-loads all `*_handler.rb` files from the configured `events_dir` (default: `app/events`). In development, the event bus is cleared before reloading to prevent duplicate subscriptions:

```
app/events/gold_transferred_handler.rb  →  GoldTransferredHandler
app/events/message_dispatched_handler.rb →  MessageDispatchedHandler
```

## Railtie extensions

The Railtie also wires up additional features when their dependencies are available:

| Extension | Loads when | What it adds |
| --- | --- | --- |
| Controller helpers | `ActionController` loads | `run_service` and `render_service_error` on all controllers |
| Async execution | `ActiveJob` loads | `.call_async` on all services |
| Lazy resolvers | `ActiveRecord` loads | `lazily` DSL on all services |

These are loaded via `ActiveSupport.on_load`, so they only activate when the corresponding Rails component is present.
