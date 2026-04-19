# Core Overview

Servus exists to express business logic as explicit, testable operations. Instead of leaving orchestration scattered across controllers, models, jobs, callbacks, and helpers, Servus encourages one business action to become one service class with one public entry point and one standard response contract.

## Core concepts

| Concept | Description |
| --- | --- |
| `Servus::Base` | The base class that provides the orchestration layer |
| `.call` | The class-level entry point callers use to run a service |
| Response object | A standard wrapper that reports success or failure |
| Schema validation | Optional argument and result validation |
| Guards | Reusable validation units for preconditions |
| Event handlers | A way to fan out follow-up work without coupling it into the service |
| `call_async` | Background execution through ActiveJob |

## When Servus helps most

Servus becomes especially useful once a codebase has meaningful business processes that cross more than one model or system boundary. A controller that checks policy, updates two records, calls an external dependency, sends a notification, and conditionally queues work is already expressing a domain action. Servus gives that action a proper home.

## What belongs in a service

A good service represents a named action with a clear success or failure state. In RavenPay, examples such as `Treasury::TransferGold::Service`, `Ravens::DispatchMessage::Service`, and `Watch::AssignRotation::Service` are good fits because each describes real business work.

## What does not automatically need a service

Passive formatting helpers, plain value objects, or model-level persistence details often do not need the full framework. Servus is strongest where orchestration, validation, policy, or side effects need to be expressed clearly.
