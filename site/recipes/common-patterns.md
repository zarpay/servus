# Common Patterns

This section collects recurring ways teams use Servus once the basics are in place. The goal is not to turn every service into the same shape. The goal is to make successful patterns easier to recognize.

## Parent-child orchestration

A parent service can coordinate several narrower services while still preserving clear boundaries. The parent should remain the place where the business workflow is named, while child services keep individual steps easy to test.

## Idempotent work

Services that may be retried or called more than once should make their success criteria explicit. An idempotent service is often easier to reason about because callers do not need to guess what happens on repeated execution.

## Async persistence pattern

When a caller needs an immediate acknowledgement but the real work happens later, a service can create a placeholder record synchronously and then use `call_async` for the heavier part of the workflow.
