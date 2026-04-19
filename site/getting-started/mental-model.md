# The Servus Mental Model

Servus works best when you think of each service as a narrow domain endpoint. Controllers, jobs, and other services call into that endpoint. The framework then wraps the domain action with consistent operational behavior so teams do not have to recreate the same execution discipline for every class.

## The model in one table

| Element | Role |
| --- | --- |
| Service class | Names and performs one business action |
| `.call` | The class-level entry point that runs the framework lifecycle |
| `call` instance method | The place where business logic is executed |
| Response object | A standard success or failure wrapper |
| Framework features | Validation, logging, async execution, guards, and events |

## Why this feels different from plain service objects

Many Ruby codebases already contain classes named `SomethingService`. What Servus adds is a real execution model around those classes. That model is what makes the framework useful at scale. A reader can expect the same response semantics, the same validation hooks, and the same extension points across the codebase.

## A simple rule for reading services

When you read a Servus service, assume that the `call` method should contain the business decision. Private methods can support that decision, but they should not become a second response layer or a second orchestration layer. That rule keeps service classes readable even as the system grows.

## Where the framework stops

Servus provides the service framework. A codebase may still add its own conventions for declaration style, schema naming, controller wrappers, or testing style. This handbook keeps those conventions visible, but it describes them separately so the framework remains legible on its own.
