# Generators

Servus ships with three Rails generators for scaffolding services, events, and guards.

## `servus:service`

Generates a service class, spec, and schema files.

```bash
rails g servus:service treasury/transfer_gold from_account to_account gold_dragons

=> create  app/services/treasury/transfer_gold/service.rb
=> create  spec/services/treasury/transfer_gold/service_spec.rb
=> create  app/schemas/services/treasury/transfer_gold/result.json
=> create  app/schemas/services/treasury/transfer_gold/arguments.json
```

| Argument | Description |
| --- | --- |
| `name` | **Required.** The namespaced service name (e.g., `treasury/transfer_gold`) |
| `parameters` | Optional. Keyword arguments for `initialize` (e.g., `from_account to_account gold_dragons`) |

| Option | Description |
| --- | --- |
| `--no-docs` | Skip YARD documentation comments in generated files |

When parameters are provided, the generated service includes `initialize` with kwargs, instance variable assignments, and `attr_reader` declarations.

## `servus:event`

Generates an Event class and spec.

```bash
rails g servus:event gold_transferred

=> create  app/events/gold_transferred.rb
=> create  spec/app/events/gold_transferred_spec.rb
```

| Argument | Description |
| --- | --- |
| `name` | **Required.** The event name in snake_case (e.g., `gold_transferred`) |

| Option | Description |
| --- | --- |
| `--no-docs` | Skip YARD documentation comments in generated files |

The generated class inherits from `Servus::Event` with a payload schema placeholder. The event name is inferred from the class name.

## `servus:guard`

Generates a guard class and spec.

```bash
rails g servus:guard eligible_transfer

=> create  app/guards/eligible_transfer_guard.rb
=> create  spec/guards/eligible_transfer_guard_spec.rb
```

| Argument | Description |
| --- | --- |
| `name` | **Required.** The guard name in snake_case, without the `Guard` suffix (e.g., `eligible_transfer`) |

| Option | Description |
| --- | --- |
| `--no-docs` | Skip YARD documentation comments in generated files |

The generated guard includes `http_status`, `error_code`, `message`, and a placeholder `test` method. It automatically defines `enforce_eligible_transfer!` and `check_eligible_transfer?` on all services.

## Configuration

All generators respect the directory settings in `Servus.configure`. If you've changed `schemas_dir`, `events_dir`, `guards_dir`, or `tests_dir`, the generated file paths follow those settings:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.schemas_dir  = "config/schemas"     # default: "app/schemas"
  config.events_dir   = "app/domain_events"  # default: "app/events"
  config.guards_dir   = "lib/guards"         # default: "app/guards"
  config.services_dir = "app/services"       # default: "app/services"
  config.tests_dir    = "test"               # default: "spec"
end
```

See [Configuration](/rails/configuration) for all available options.
