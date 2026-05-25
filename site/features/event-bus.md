# Events

Services can emit events that trigger follow-up work without absorbing every downstream concern into the `call` method. One successful transfer can notify a ledger, send a receipt, and update analytics — without the transfer service knowing any of that exists.

## Emitting events

Declare events with the `emits` DSL. The framework fires them automatically after [result validation](/core/call-chain#_6-validate-the-result):

```ruby
class Treasury::TransferGold::Service < Servus::Base
  emits :gold_transferred_event, on: :success
  emits :transfer_failed_event, on: :failure
  emits :transfer_error_event, on: :error!

  def call
    from_account.withdraw!(@gold_dragons)
    to_account.deposit!(@gold_dragons)

    success(
      transferred: @gold_dragons,
      from_balance: from_account.balance,
      to_balance: to_account.balance
    )
  end
end
```

### Default payloads

| Trigger | Payload |
| --- | --- |
| `:success` | `result.data` — the hash you passed to `success(...)` |
| `:failure` | `result.error` — the `ServiceError` instance |
| `:error!` | `result.error` — emitted synchronously before the exception is raised |

### Custom payloads

Override the default payload with a block:

```ruby
emits :gold_transferred_event, on: :success do |result|
  {
    from: result.data.from_balance,
    to: result.data.to_balance,
    amount: result.data.transferred
  }
end
```

Or a method reference:

```ruby
emits :gold_transferred_event, on: :success, with: :transfer_payload

private

def transfer_payload(result)
  {
    from: result.data.from_balance,
    to: result.data.to_balance,
    amount: result.data.transferred
  }
end
```

### Conditional emission

Use `if:` or `unless:` to gate whether an event fires at runtime. When the condition is not met, the event is completely skipped — no payload is built, no validation runs, and nothing reaches the bus.

Both options accept a **lambda/proc** or a **method reference** (Symbol). The condition always receives the `result` object, giving it access to `result.data`, `result.error`, `result.success?`, and `result.failure?`.

::: info Conditions vs payload builders
The `&block` position on `emits` is already taken by the payload builder. Conditions must be passed as `if:` or `unless:` options — a proc/lambda or a Symbol naming a private instance method.
:::

#### `if:` with a lambda

The event fires only when the lambda returns a truthy value:

```ruby
class Treasury::TransferGold::Service < Servus::Base
  # Only notify the Iron Bank for large transfers
  emits :large_transfer_event, on: :success, if: ->(result) { result.data[:transferred] > 100 }

  def call
    from_account.withdraw!(@gold_dragons)
    to_account.deposit!(@gold_dragons)
    success(transferred: @gold_dragons, from_balance: from_account.balance, to_balance: to_account.balance)
  end
end
```

#### `unless:` with a lambda

The event fires only when the lambda returns a falsy value:

```ruby
class Treasury::TransferGold::Service < Servus::Base
  # Skip the standard receipt for large transfers (they get a different event)
  emits :standard_transfer_event, on: :success, unless: ->(result) { result.data[:transferred] > 100 }

  def call
    # ...
  end
end
```

#### `if:` with a method reference

Pass a Symbol to call a private instance method. The method receives the same `result` object:

```ruby
class Treasury::TransferGold::Service < Servus::Base
  emits :vip_transfer_event, on: :success, if: :vip_sender?

  def call
    from_account.withdraw!(@gold_dragons)
    to_account.deposit!(@gold_dragons)
    success(transferred: @gold_dragons, account_tier: from_account.tier)
  end

  private

  def vip_sender?(result)
    result.data[:account_tier] == :vip
  end
end
```

#### `unless:` with a method reference

```ruby
class Treasury::TransferGold::Service < Servus::Base
  emits :transfer_failed_event, on: :failure, unless: :suppressed_account?

  def call
    # ...
  end

  private

  def suppressed_account?(result)
    result.error.message.include?("suppressed")
  end
end
```

#### Combining `if:` and `unless:`

Both conditions must pass for the event to emit. If either blocks, the event is skipped:

```ruby
class Treasury::TransferGold::Service < Servus::Base
  emits :audit_transfer_event, on: :success,
    if: ->(result) { result.data[:transferred] > 50 },
    unless: :internal_transfer?

  def call
    # ...
  end

  private

  def internal_transfer?(result)
    @to_account.internal?
  end
end
```

::: tip Emission vs invocation conditions
`if:`/`unless:` on `emits` gate the **event itself** — when the condition fails, the event never enters the bus and no handlers run.

The `if:`/`unless:` on `invoke` (inside an Event class) gate a **specific handler** — the event fires and reaches the bus, but only matching handlers are invoked. Use emission conditions when the entire event is irrelevant; use invocation conditions when only some handlers should react.
:::

## Handling events

A service can emit events without knowing or caring whether anything is listening. The service's job ends when the event fires — it has no dependency on what happens next.

When you want to react to an event, you create an Event class. An Event class subscribes to a single event name and declares which services to invoke when that event fires. It inherits from `Servus::Event`, uses `event_name` to set (or override) the name, and uses `invoke` to wire up each response. The Event class's job is purely coordination — it maps the event payload to service arguments and decides whether to run sync or async. No business logic belongs here.

Generate one with the Rails generator:

```bash
rails g servus:event gold_transferred

=> create app/events/gold_transferred_event.rb
=> create spec/events/gold_transferred_event_spec.rb
```

Then declare what services should react to the event:

```ruby
# app/events/gold_transferred_event.rb
class GoldTransferredEvent < Servus::Event
  # event name inferred as :gold_transferred_event from class name

  invoke Ledger::RecordEntry::Service, async: true do |payload|
    { transfer: payload[:transfer] }
  end

  invoke Ravens::SendReceipt::Service, async: true do |payload|
    { amount: payload[:transferred], from: payload[:from_balance] }
  end
end
```

Each `invoke` block maps the event payload to the service's keyword arguments. A single Event class can invoke multiple services — they all react to the same event. If no block is given, the full payload is passed through as params.

### Sync vs async invocation

Event classes can invoke services synchronously (inline) or asynchronously (enqueued via ActiveJob):

```ruby
# Synchronous (default) — runs inline
invoke IronBank::NotifyMasterOfCoin::Service do |payload|
  { message: "Transfer of #{payload[:transferred]} gold dragons completed" }
end

# Asynchronous — enqueued via ActiveJob
invoke Ravens::SendReceipt::Service, async: true do |payload|
  { amount: payload[:transferred] }
end

# Async with a specific queue
invoke Ravens::SendReceipt::Service, async: true, queue: :mailers do |payload|
  { amount: payload[:transferred] }
end
```

::: warning Prefer async invocation
Synchronous invocations run inline during the emitting service's `after_call` phase — before the result is returned to the caller. If a sync invocation raises an exception, it propagates through the emitting service and the caller never receives the result. Async invocation avoids this entirely — the work is enqueued and runs independently. Use sync only when the follow-up must complete before the caller gets a response.
:::

### Conditional invocation

Invocations can be gated with `if:` or `unless:` lambdas that receive the event payload. The service is only invoked when the condition passes:

```ruby
# Only when the transfer exceeds 100 gold dragons
invoke Ravens::DispatchMessage::Service, async: true, if: ->(p) { p[:transferred] > 100 } do |payload|
  {
    message: "Large transfer of #{payload[:transferred]} gold dragons completed",
    destination: :iron_bank
  }
end

# Only when the transfer does NOT exceed 100 gold dragons
invoke Ravens::DispatchMessage::Service, async: true, unless: ->(p) { p[:transferred] > 100 } do |payload|
  {
    message: "Transfer of #{payload[:transferred]} gold dragons completed",
    destination: :iron_bank
  }
end

# Both conditions can be combined with sync or async
invoke Ravens::DispatchMessage::Service, if: ->(p) { p[:transferred] > 100 } do |payload|
  {
    message: "Large transfer of #{payload[:transferred]} gold dragons completed",
    destination: :iron_bank
  }
end
```

## Payload schema validation

Event classes can define a JSON Schema to validate event payloads. Payload validation runs on both emission paths — the `emits` DSL and `Event.emit`. When a payload doesn't match the Event's schema, Servus raises a `ValidationError` before any invocations run.

```ruby
class GoldTransferredEvent < Servus::Event
  schema payload: {
    type: "object",
    required: ["transferred", "from_balance", "to_balance"],
    properties: {
      transferred: { type: "number" },
      from_balance: { type: "number" },
      to_balance: { type: "number" }
    }
  }

  invoke Ledger::RecordEntry::Service, async: true do |payload|
    { amount: payload[:transferred] }
  end
end
```

## Emitting events without a service

Event classes provide an `emit` class method for triggering events from controllers, jobs, or other code that isn't a Servus service:

```ruby
class TransfersController < ApplicationController
  after_action :emit_transfer_event, only: :create

  def create
    @transfer = Transfer.create!(transfer_params)
    render json: @transfer, status: :created
  end

  private

  def emit_transfer_event
    GoldTransferredEvent.emit({
      transferred: @transfer.amount,
      from_balance: @transfer.from_account.balance,
      to_balance: @transfer.to_account.balance
    })
  end
end
```

When a payload schema is defined on the Event class, `emit` validates the payload before dispatching.

## Event name inference

The event name is inferred from the class name by default — `GoldTransferredEvent` becomes `:gold_transferred_event`. You can override this with an explicit `event_name` call:

```ruby
class GoldTransferredEvent < Servus::Event
  event_name :custom_gold_event  # overrides inference
end
```

Each event name maps to exactly one Event class. Attempting to register a second class for the same name raises an error.

## Routing

When `Bus.emit` fires, it delegates to configured routers to resolve which services to invoke. Each router returns a list of `Invocation` objects; the Bus deduplicates by key (first wins) and executes.

Servus ships with `ClassRouter` as the default — it reads `invoke` declarations from Event classes. Applications can add additional routers (e.g. a data-driven router backed by a database) via configuration:

```ruby
Servus.configure do |config|
  config.routers = [
    Servus::Events::ClassRouter.new,
    MyApp::DataDrivenRouter.new
  ]
end
```

Routers are processed in array order. Invocations within each router preserve declaration order. This ordering is a guarantee, not an implementation detail.

## Conventions

### Location and namespacing

Event classes live in `app/events/` and should always stay top-level — no namespacing. Events are global by design. They exist as an orchestration layer across decoupled domains, not within any single one.

This is intentional. A service inside one Rails engine can emit an event, and an Event class at the project root can subscribe to it and invoke services in a completely different engine. Namespacing Event classes inside a domain would defeat that purpose.

```
app/events/
├── gold_transferred_event.rb
├── message_dispatched_event.rb
└── account_closed_event.rb
```

### Naming

- **Files**: `_event.rb` suffix — `gold_transferred_event.rb`, `message_dispatched_event.rb`
- **Classes**: PascalCase with `Event` suffix — `GoldTransferredEvent`, `MessageDispatchedEvent`
- **Event names**: inferred from class name — `:gold_transferred_event`, `:message_dispatched_event`

## Instrumentation

Every event is dispatched through `ActiveSupport::Notifications` with the prefix `servus.events.`. This means Servus events automatically appear in Rails logs with timing and payload data — and you can subscribe to them programmatically for monitoring, metrics, or debugging.

### Subscribe to all Servus events

`Bus.subscribe_all` yields every emission with clean arguments — no regex or prefix stripping needed:

```ruby
Servus::Events::Bus.subscribe_all do |event_name, payload, started_at:, finished_at:, **|
  duration = ((finished_at - started_at) * 1000).round(1)
  Rails.logger.info "[Servus Event] #{event_name} (#{duration}ms) #{payload}"
end
```

```
[Servus Event] gold_transferred_event (1.2ms) {:transferred=>50, :from_balance=>950, :to_balance=>550}
```

The block receives `event_name` and `payload` as positional args, plus `started_at:`, `finished_at:`, and `id:` as keyword args. The `id` is a unique identifier per emission — use it for log correlation. Use `**` to ignore keywords you don't need.

```ruby
# Forward all events to an external system
Servus::Events::Bus.subscribe_all do |event_name, payload, started_at:, **|
  EventusForwardJob.perform_later(
    event: event_name.to_s,
    payload: payload.as_json,
    occurred_at: started_at.utc.iso8601(6)
  )
end
```

The method returns the subscription object for manual unsubscribe:

```ruby
subscription = Servus::Events::Bus.subscribe_all { |event_name, payload, **| ... }
ActiveSupport::Notifications.unsubscribe(subscription)
```

### Subscribe to a specific event

For subscribing to a single event, use `ActiveSupport::Notifications` directly:

```ruby
ActiveSupport::Notifications.subscribe("servus.events.gold_transferred_event") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  StatsD.increment("transfers.completed")
  StatsD.measure("transfers.amount", event.payload[:transferred])
end
```

### Common uses

- **Metrics** — count events, measure payload values, track invocation duration
- **Alerting** — trigger alerts on specific events or unusual patterns
- **Audit logging** — write event payloads to an audit trail outside the Event class
- **Debugging** — temporarily subscribe to see what's flowing through the bus
