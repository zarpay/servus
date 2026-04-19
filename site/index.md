---
layout: home
hero:
  name: Servus
  text: A framework for business actions in Ruby and Rails
  tagline: Rails gives you strong places for requests, persistence, and background execution. What it does not give you is a strong home for business actions that coordinate all three. Servus fills that gap by giving each action a clear boundary, a standard entrypoint, and a consistent result.
  actions:
    - theme: brand
      text: Start with Quick Start
      link: /getting-started/
    - theme: alt
      text: Explore Core Concepts
      link: /core/overview
features:
  - title: A Home for Business Actions
    details: "Put orchestration where it belongs: in a named service, not split across controllers, models, and jobs."
  - title: Standard Runtime Model
    details: "Use one entrypoint, one response shape, and one predictable lifecycle across the codebase."
  - title: Operational by Default
    details: "Validation, guards, logging, events, and async execution stay attached to the action itself."
  - title: One Coherent Example System
    details: "RavenPay keeps the examples consistent across services, events, async work, and tests."
---

## What Servus is

Servus is a framework for service objects in Ruby and Rails. It is built for business actions that deserve their own boundary: actions like transferring funds, settling a ledger, dispatching a message, or onboarding an account. These actions usually touch more than one Rails layer, but they do not belong cleanly to any one of them.

Servus gives those actions a proper home. A service becomes the place where the action is named, executed, and reported. That makes the code easier to call, easier to test, and easier to grow.

## The gap it fills in Rails

Rails gives you controllers for handling requests, models for persistence and domain state, and background jobs for deferred execution. Those are all important parts of an application, but none of them is designed to be the primary home for a business action that coordinates multiple concerns.

When an action has to validate input, enforce rules, update records, emit events, write logs, and sometimes continue asynchronously, teams often have to improvise. Part of the action ends up in a controller, part in a model, part in a callback, and part in a job. The framework gives you places to put the pieces, but not a strong boundary for the action itself.

| Rails layer | What it is good at | What goes wrong when it becomes the home for a business action |
| --- | --- | --- |
| Controller | Accepting a request and shaping an HTTP response | The action becomes coupled to the web layer and harder to reuse outside a request |
| Model | Representing persistence and domain state | Orchestration gets mixed into persistence concerns and spreads through callbacks and class methods |
| Background job | Running work later or elsewhere | The job becomes both scheduler and business action, making execution flow harder to reason about |

## What you lose without a service boundary

When business actions are spread across these layers, the code still works for a while, but the costs accumulate. The action no longer has one obvious name, one obvious entrypoint, or one obvious place to test. Callers have to know too much about how the work is wired together. Readers have to reconstruct the flow by jumping between framework layers.

| What you lose | How it shows up |
| --- | --- |
| **Clarity** | The business action has no single place to read from top to bottom |
| **Reusability** | The action is tied to HTTP, persistence callbacks, or job execution details |
| **Consistency** | Similar actions return different shapes and follow different calling conventions |
| **Testability** | Behavior is locked up in multiple layers instead of one focused unit |
| **Operational discipline** | Logging, events, validation, and async behavior are added differently each time |

## How Servus responds

Servus treats the business action itself as a first-class concept. A named service owns the action. Callers use `.call`. The service returns a response object. Framework features such as schemas, guards, logging, emitted events, and async execution stay attached to the same boundary.

That changes the shape of the codebase. Instead of asking whether a piece of business logic belongs in the controller, the model, or the job, the question becomes simpler: what is the action, and what service owns it?

| Pressure in the codebase | Servus response |
| --- | --- |
| One action touches many layers | Give the action one named service boundary |
| Callers need predictable outcomes | Return a standard response object |
| Side effects need discipline | Keep events, logging, and async behavior attached to the service |
| Teams need repeatable patterns | Use the same lifecycle across the codebase |

## How to read the handbook

The handbook moves from fundamentals to features, then to Rails integration, testing, production patterns, and reference material. That order starts with the action boundary itself, then shows how it fits into a full Rails application.

| Reading goal | Start here | Then continue to |
| --- | --- | --- |
| Understand the framework quickly | **Quick Start** | **The Servus Mental Model** |
| Learn the execution model | **Core Overview** | **Responses** and **Architecture** |
| Explore framework capabilities | **Schema Validation** | **Guards**, **Event Bus**, and **Async Execution** |
| Use Servus inside Rails | **Controllers** | **Configuration** and **Background Jobs** |
| Follow one end-to-end example | **RavenPay Walkthrough** | **Common Patterns** and **Migration** |

## The running example: RavenPay

RavenPay is the fictional system used throughout the handbook. It is a treasury, settlement, and dispatch platform shared across Westeros, and it gives the docs one consistent vocabulary for services, events, guards, and async work.

| Concern | RavenPay example | What it demonstrates |
| --- | --- | --- |
| Service | `Treasury::TransferGold::Service` | A business action with a clear boundary and response contract |
| Guard | `OpenAccountGuard` | Domain rules checked before work proceeds |
| Event | `:gold_transferred` | Follow-up behavior triggered from a successful action |
| Async work | `Ravens::DispatchMessage::Service.call_async(...)` | Deferred execution through the same service boundary |
| Testing | Transfer, guard, and event specs | The action tested as one coherent unit |
