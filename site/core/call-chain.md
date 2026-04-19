# Call Chain

A central Servus rule is that callers should use the class method `.call` instead of manually instantiating and invoking a service. That rule matters because the framework behavior lives around the class-level entry point.

## What `.call` gives you

| Behavior | Why it matters |
| --- | --- |
| Consistent service construction | Callers do not need to know initialization details |
| Validation hooks | Arguments and results can be validated predictably |
| Logging and benchmarking | Observability stays in one place |
| Failure normalization | Callers always receive the response shape they expect |
| Event and async integration | Cross-cutting behavior stays off the business path |

## Good versus bad call sites

```ruby
# Good
result = Treasury::TransferGold::Service.call(
  from_account: crown_account,
  to_account: wall_account,
  gold_dragons: 50
)
```

```ruby
# Avoid
service = Treasury::TransferGold::Service.new(
  from_account: crown_account,
  to_account: wall_account,
  gold_dragons: 50
)
result = service.call
```

## Why this discipline helps in larger systems

Once many services exist, consistency is more valuable than convenience. Teams can reason about behavior more quickly when every service enters through the same door and every cross-cutting concern stays attached to that door.
