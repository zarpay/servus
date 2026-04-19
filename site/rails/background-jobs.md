# Rails Background Jobs

`call_async` is Servus's bridge into Rails background processing. It lets a team reuse the service boundary instead of splitting the business action into one service for sync code and one bespoke job for async code.

## The main idea

If the background job is simply “run this business action later,” a service with `call_async` is usually a better starting point than a custom job class. The service keeps validation, logging, and response semantics attached to the same unit of work.

## When a separate job may still make sense

A separate job can still be appropriate when the job itself is mostly workflow coordination or when it is orchestrating multiple services rather than representing a single business action.
