# Lazy Resolvers

Lazy resolvers help services accept references that can be turned into records only when they are actually needed. That can make services more flexible in both synchronous and asynchronous use.

## The problem they solve

A caller may naturally hold either a fully loaded record or an identifier. Without a resolver, the service author often has to choose one style and force every caller to adapt. A lazy resolver can accept a broader input shape while keeping the lookup logic centralized.

## Conceptual example

```ruby
class Ravens::DispatchMessage::Service < Servus::Base
  lazily :rookery, finds: Rookery, by: :uuid

  def initialize(rookery:, message:)
    @rookery = rookery
    @message = message
  end

  def call
    success(dispatch_id: RookeryGateway.deliver(@rookery, @message))
  end
end
```

## Why laziness matters

| Benefit | Practical result |
| --- | --- |
| Deferred lookup | A record is only loaded if the service actually uses it |
| Flexible callers | Code can pass a record or a lookup-friendly reference |
| Async portability | Identifiers are easier to enqueue than rich Ruby objects |

## Relationship to production conventions

In ZAR Core, lazy resolvers are often seen together with Dry Initializer `option` declarations. That pairing can work well, but it should be documented as a production convention and compatibility story rather than as the framework's opening definition.
