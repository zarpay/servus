# Rails Generators

Servus ships with generators so teams can create services and related files with a consistent structure. That consistency matters because the framework is easier to adopt when services start from the same baseline.

## Service generator

```bash
rails g servus:service treasury/transfer_gold from_account to_account gold_dragons
```

## What it creates

| File | Purpose |
| --- | --- |
| `app/services/.../service.rb` | The service entry point |
| `spec/services/.../service_spec.rb` | The corresponding test scaffold |
| schema files | Input and result contracts where configured |

## Why the generator matters

The generator is not just about speed. It nudges teams toward a consistent directory layout, naming scheme, and testing habit from the moment a service is created.
