# Instrumentation

Servus sends an [ActiveSupport notification](https://guides.rubyonrails.org/active_support_instrumentation.html) around every service call, every `call_async` and every event emit. Subscribe to them to trace, log or measure services.

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



| Outcome | When |
| --- | --- |
| `:success` | The response is a success |
| `:failure` | A failure response that is not a guard: `failure`, `failure!`, or an exception that `rescue_from` handles |
| `:guard` | A guard failed |
| `:invalid_arguments` | The arguments failed their schema |
| `:invalid_result` | The result (or failure data) failed its schema |
| `:invalid_event` | An emitted event's payload failed its schema |
| `:exception` | Any other exception raised out of the call, or a `throw` through it |


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
