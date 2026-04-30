# Events

Services can emit events that trigger follow-up work without absorbing every downstream concern into the `call` method. One successful transfer can notify a ledger, send a receipt, and update analytics — without the transfer service knowing any of that exists.

## Emitting events

Declare events with the `emits` DSL. The framework fires them automatically after [result validation](/core/call-chain#_6-validate-the-result):

```ruby
class Treasury::TransferGold::Service < Servus::Base
  emits :gold_transferred, on: :success
  emits :transfer_failed, on: :failure
  emits :transfer_error, on: :error!

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
emits :gold_transferred, on: :success do |result|
  {
    from: result.data.from_balance,
    to: result.data.to_balance,
    amount: result.data.transferred
  }
end
```

Or a method reference:

```ruby
emits :gold_transferred, on: :success, with: :transfer_payload

private

def transfer_payload(result)
  {
    from: result.data.from_balance,
    to: result.data.to_balance,
    amount: result.data.transferred
  }
end
```

## Handling events

A service can emit events without knowing or caring whether anything is listening. The service's job ends when the event fires — it has no dependency on what happens next.

When you want to react to an event, you create a handler. A handler is a class that subscribes to a single event and declares which services to invoke when that event fires. It inherits from `Servus::EventHandler`, uses `handles` to name the event, and uses `invoke` to wire up each response. The handler's job is purely coordination — it maps the event payload to service arguments and decides whether to run sync or async. No business logic belongs here.

Generate one with the Rails generator:

```bash
rails g servus:event_handler gold_transferred

=> create app/events/gold_transferred_handler.rb
=> create spec/events/gold_transferred_handler_spec.rb
```

Then declare what services should react to the event:

```ruby
# app/events/gold_transferred_handler.rb
class GoldTransferredHandler < Servus::EventHandler
  handles :gold_transferred

  invoke Ledger::RecordEntry::Service, async: true do |payload|
    { transfer: payload[:transfer] }
  end

  invoke Ravens::SendReceipt::Service, async: true do |payload|
    { amount: payload[:transferred], from: payload[:from_balance] }
  end
end
```

Each `invoke` block maps the event payload to the service's keyword arguments. A single handler can invoke multiple services — they all react to the same event.

### Sync vs async invocation

Handlers can invoke services synchronously (inline) or asynchronously (enqueued via ActiveJob):

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
Synchronous handlers run inline during the emitting service's `after_call` phase — before the result is returned to the caller. If a sync handler raises an exception, it propagates through the emitting service and the caller never receives the result. Async invocation avoids this entirely — the handler work is enqueued and runs independently. Use sync only when the follow-up must complete before the caller gets a response.
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

Handlers can define a JSON Schema to validate event payloads. Payload validation runs on both emission paths — the `emits` DSL and `Handler.emit`. When a payload doesn't match the handler's schema, Servus raises a `ValidationError` before any handler logic runs.

```ruby
class GoldTransferredHandler < Servus::EventHandler
  handles :gold_transferred

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

Handlers provide an `emit` class method for triggering events from controllers, jobs, or other code that isn't a Servus service:

```ruby
class TransfersController < ApplicationController
  after_action :emit_transfer_event, only: :create

  def create
    @transfer = Transfer.create!(transfer_params)
    render json: @transfer, status: :created
  end

  private

  def emit_transfer_event
    GoldTransferredHandler.emit({
      transferred: @transfer.amount,
      from_balance: @transfer.from_account.balance,
      to_balance: @transfer.to_account.balance
    })
  end
end
```

When a payload schema is defined on the handler, `emit` validates the payload before dispatching.

## Conventions

### Location and namespacing

Handlers live in `app/events/` and should always stay top-level — no namespacing. Events are global by design. They exist as an orchestration layer across decoupled domains, not within any single one.

This is intentional. A service inside one Rails engine can emit an event, and a handler at the project root can subscribe to it and invoke services in a completely different engine. Namespacing handlers inside a domain would defeat that purpose.

```
app/events/
├── gold_transferred_handler.rb
├── message_dispatched_handler.rb
└── account_closed_handler.rb
```

### Naming

- **Events**: past tense describing what happened — `:gold_transferred`, `:message_dispatched`
- **Handlers**: event name + `Handler` suffix — `GoldTransferredHandler`, `MessageDispatchedHandler`

## Strict event validation

Enable strict validation to catch handlers that subscribe to events no service emits:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.strict_event_validation = true  # default
end

# In a rake task or CI
Servus::EventHandler.validate_all_handlers!
```

This raises `OrphanedHandlerError` if any handler subscribes to a non-existent event — catches typos and stale handlers.

## Instrumentation

Every event is dispatched through `ActiveSupport::Notifications` with the prefix `servus.events.`. This means Servus events automatically appear in Rails logs with timing and payload data — and you can subscribe to them programmatically for monitoring, metrics, or debugging.

### Subscribe to all Servus events

```ruby
ActiveSupport::Notifications.subscribe(/^servus\.events\./) do |name, start, finish, id, payload|
  event_name = name.sub("servus.events.", "")
  duration = ((finish - start) * 1000).round(1)
  Rails.logger.info "[Servus Event] #{event_name} (#{duration}ms) #{payload}"
end
```

```
[Servus Event] gold_transferred (1.2ms) {:transferred=>50, :from_balance=>950, :to_balance=>550}
```

### Subscribe to a specific event

```ruby
ActiveSupport::Notifications.subscribe("servus.events.gold_transferred") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  StatsD.increment("transfers.completed")
  StatsD.measure("transfers.amount", event.payload[:transferred])
end
```

### Common uses

- **Metrics** — count events, measure payload values, track handler duration
- **Alerting** — trigger alerts on specific events or unusual patterns
- **Audit logging** — write event payloads to an audit trail outside the handler
- **Debugging** — temporarily subscribe to see what's flowing through the bus
