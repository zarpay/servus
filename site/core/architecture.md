# Architecture

Servus wraps a small but important architecture around a straightforward service-object idea. The point is not to make services abstract. The point is to make business actions predictable.

## Execution flow

| Phase | What happens |
| --- | --- |
| Construction | The service is created with keyword arguments |
| Validation | Arguments may be checked against a schema |
| Execution | Your `call` method performs business work |
| Result handling | Success and failure responses are normalized |
| Instrumentation | Logging and benchmarking can record the call |
| Side effects | Events and async integrations can react consistently |

## Core components

| Component | Role |
| --- | --- |
| `Servus::Base` | The service runtime |
| Response object | Standardized return contract |
| Schema support | Contract checking before and after execution |
| Guard layer | Reusable validation units |
| Event layer | Decoupled follow-up processing |
| Async adapter | Background execution via ActiveJob |

## Why the architecture scales

In a small application, the framework may feel like a disciplined wrapper around plain Ruby. In a large one, the consistency is what matters. Readers can trust that services behave similarly, failure modes look similar, and extension points are attached in the same places.
