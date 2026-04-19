# Async Execution

Servus supports background execution through `call_async`, allowing the same service contract to run through ActiveJob. This is often preferable to creating a bespoke job immediately because the validation, logging, and response semantics remain attached to the service boundary.

## Basic usage

```ruby
Ravens::DispatchMessage::Service.call_async(
  rookery_id: castle_black_rookery.id,
  recipient: 'winterfell',
  message: 'The Wall stands',
  queue: :communications,
  priority: 10
)
```

## Sync and async compared

| Concern | `.call` | `.call_async` |
| --- | --- | --- |
| Return value | Immediate response object | Enqueue result from ActiveJob |
| Caller expectation | Inspect success or failure now | Observe outcome through persistence, logs, or events |
| Argument choice | Ruby objects may work in-process | Prefer IDs and portable values |

## When async execution is a good fit

Async execution works well for notifications, reconciliation, report generation, and non-blocking follow-up tasks. It is a poor fit for operations where the caller needs a result in the same request cycle.

## Design rule

If a service may run both synchronously and asynchronously, design its arguments to be portable. That makes the service easier to enqueue safely and easier to call from different parts of the application.
