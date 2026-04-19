# The Servus Mental Model

## How to think about services

A Servus service is an internal API for a business action. Controllers, models, jobs, other services, and rake tasks all call it the same way — `Service.call(**args)` — and get back the same `Response`. When the work should happen in the background, `Service.call_async(**args)` enqueues it through ActiveJob without changing the service itself.

The caller doesn't need to know how the service works internally. It passes arguments, gets a response, and branches on `success?` if necessary. That contract holds whether the caller is a controller rendering JSON, a job running in the background, or another service composing a larger workflow.

## The execution lifecycle

When you call `Service.call(**args)`, your `call` method isn't invoked directly. Servus wraps it in a lifecycle that handles validation, timing, error handling, event emission, and logging automatically.

```
Service.call(**args)
  │
  ├── Log the call and arguments
  ├── Validate arguments against schema (if defined)
  ├── Instantiate the service
  ├── Run your `call` method
  ├── Validate the result against schema (if defined)
  ├── Emit events (if defined)
  ├── Log success or failure with duration
  │
  └── Return Response
```

Your `call` method only contains business logic. Everything above and below it is handled by the runtime.

## Why this matters in practice

**Testability.** When the business logic lives behind `Service.call(**args) → Response`, you test it by passing arguments and asserting on the response. No controller setup, no job infrastructure, no request context. Inputs in, outputs out.

**Reusability.** A service isn't tied to a controller action, a callback, or a job. The same service can be called from a web request, a background worker, a rake task, or another service — without changing anything.

**Discoverability.** The service name is the action name. `Treasury::TransferGold::Service` tells you what it does and where to find it (`app/services/treasury/transfer_gold/service.rb`). When something breaks, you grep one name and land in one file.

## One rule for reading services

The `call` method should contain the business decision. Private methods and `Support::` classes can support it, but they should not become a second response layer or a second orchestration boundary. If a private method is returning `success` or `failure`, it probably belongs in its own service.
