# Instrumentation

Servus sends an [ActiveSupport notification](https://guides.rubyonrails.org/active_support_instrumentation.html) around every service call, every `call_async` and every event emit. Subscribe to them to trace, log or measure services without reaching into Servus.

Servus takes no OpenTelemetry dependency. The notifications work with any subscriber.

## Notifications

| Name | Sent around |
| --- | --- |
| `call.servus` | `Service.call`, including `rescue_from` handling |
| `enqueue.servus` | `Service.call_async` |
| `emit.servus` | `Servus::Events::Bus.emit`, so every event emit |

The names follow the Rails `event.library` form. Payload keys are plain symbols, as in Rails' own payloads.

## call.servus

| Key | Value |
| --- | --- |
| `service` | The service class |
| `args` | The arguments, filtered with `log_filter_parameters` when it is set |
| `response` | The `Servus::Support::Response`, when the call returns one |
| `outcome` | One symbol for how the call ended (see below) |
| `exception`, `exception_object` | Set by ActiveSupport when the call raises |

`outcome` is one of:

| Outcome | When |
| --- | --- |
| `:success` | The response is a success |
| `:failure` | A failure response that is not a guard: `failure`, `failure!`, or an exception that `rescue_from` handles |
| `:guard` | A guard failed |
| `:invalid_arguments` | The arguments failed their schema |
| `:invalid_result` | The result (or failure data) failed its schema |
| `:invalid_event` | An emitted event's payload failed its schema |
| `:exception` | Any other error raised out of the call |

The notification wraps `rescue_from`, so it reports what the caller gets. An exception that `rescue_from` turns into a failure shows as `:failure`, with a `response` and no `exception_object`.

When one service calls another, each call sends its own `call.servus`. The inner one finishes first, and each reports its own outcome: an inner `:invalid_arguments` reaches the outer call as `:exception`.

## enqueue.servus

| Key | Value |
| --- | --- |
| `service` | The service class |
| `args` | The service arguments, without ActiveJob options, filtered as for `call.servus` |
| `job` | What `perform_later` returned |

With the `:inline` adapter, the service runs during the enqueue, so its `call.servus` is nested inside `enqueue.servus`.

## emit.servus

| Key | Value |
| --- | --- |
| `event` | The event name, a symbol |
| `service` | The emitting service class, or `nil` when the bus is called directly |
| `payload` | The event payload |

An event whose payload fails its schema never reaches the bus. It shows as `outcome: :invalid_event` on `call.servus`.

`emit.servus` wraps the `servus.events.<name>` notification the bus already sends. That one is unchanged, and so is everything that subscribes to it: `Bus.subscribe_all`, the event log line and the `emit_event` matcher.

## Subscribing

Any ActiveSupport subscriber works:

```ruby
ActiveSupport::Notifications.subscribe('call.servus') do |event|
  Rails.logger.info(
    "#{event.payload[:service].name} #{event.payload[:outcome]} in #{event.duration.round(1)}ms"
  )
end
```

## OpenTelemetry

The generic span subscriber in `opentelemetry-instrumentation-active_support` turns each notification into a span. It keeps only scalar payload values as attributes and marks the span as an error when `exception_object` is set. The raw `args`, `response`, `job` and `payload` never reach a span unless your transform puts them there.

Add the `servus.` prefix to attributes in the payload transform:

```ruby
tracer = OpenTelemetry.tracer_provider.tracer('servus')

transform = lambda do |payload|
  {
    'servus.service' => payload[:service]&.name,
    'servus.outcome' => payload[:outcome]&.to_s,
    'servus.event' => payload[:event]&.to_s
  }.compact
end

%w[call.servus enqueue.servus emit.servus].each do |name|
  OpenTelemetry::Instrumentation::ActiveSupport.subscribe(tracer, name, transform)
end
```

Choose what may go on a span before you add arguments or results to the transform.
