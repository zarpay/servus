# Instrumentation

Servus sends an [ActiveSupport notification](https://guides.rubyonrails.org/active_support_instrumentation.html) around every service call, every `call_async` and every event emit. Subscribe to them to trace, log or measure services.

`call.servus` and `enqueue.servus` do no work until something subscribes to them, so they cost nothing when unused.

## Notifications

| Name | Sent around |
| --- | --- |
| `call.servus` | `Service.call`, including `rescue_from` handling |
| `enqueue.servus` | `Service.call_async` |
| `emit.servus` | `Servus::Events::Bus.emit`, so every event emit |

## call.servus

| Key | Value |
| --- | --- |
| `service` | The service class |
| `args` | The arguments, filtered with `log_filter_parameters` when it is set |
| `response` | The `Servus::Support::Response`, when the call returns one |
| `outcome` | One symbol for how the call ended (see below) |
| `exception`, `exception_object` | Set by ActiveSupport when the call raises |

### Outcomes

| Outcome | When |
| --- | --- |
| `:success` | The response is a success |
| `:failure` | A failure response that is not a guard: `failure`, `failure!`, or an exception that `rescue_from` handles |
| `:guard` | A guard failed |
| `:exception` | An exception raised out of the call, or a `throw` through it |

When a schema check fails, the outcome is `:exception` and `exception_object` tells you which check failed:

| Error | When |
| --- | --- |
| `Servus::Support::Errors::InvalidArgumentsError` | The arguments failed their schema |
| `Servus::Support::Errors::InvalidResultError` | The result (or failure data) failed its schema |
| `Servus::Support::Errors::InvalidEventError` | An emitted event's payload failed its schema |

All three are subclasses of `ValidationError`, so `rescue ValidationError` and `rescue_from ValidationError` still catch them.

## enqueue.servus

| Key | Value |
| --- | --- |
| `service` | The service class |
| `args` | The service arguments |
| `job` | What `perform_later` returned |

## emit.servus

| Key | Value |
| --- | --- |
| `event` | The event name, a symbol |
| `service` | The service class whose `emits` declaration sent the event. |
| `payload` | The event payload |

## Subscribing

```ruby
ActiveSupport::Notifications.subscribe('call.servus') do |event|
  Rails.logger.info(
    "#{event.payload[:service].name} #{event.payload[:outcome]} in #{event.duration.round(1)}ms"
  )
end
```
