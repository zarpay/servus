# Schema Validation

Schema validation is one of Servus's clearest differentiators from informal service-object patterns. It lets a service describe valid inputs and, when needed, valid result payloads.

## How it works

Servus supports both inline schema definitions and file-based schema definitions. The framework documentation should explain both, because both belong to Servus itself. More opinionated schema naming conventions used in production codebases belong later in the handbook.

## Inline schema example

```ruby
class Treasury::TransferGold::Service < Servus::Base
  schema(
    arguments: {
      type: 'object',
      required: ['from_account_id', 'to_account_id', 'gold_dragons'],
      properties: {
        from_account_id: { type: 'integer' },
        to_account_id: { type: 'integer' },
        gold_dragons: { type: 'integer', minimum: 1 }
      }
    },
    result: {
      type: 'object',
      required: ['transfer_id'],
      properties: {
        transfer_id: { type: 'string' }
      }
    }
  )
end
```

## File-based schema example

```ruby
class Treasury::TransferGold::Service < Servus::Base
  arguments_schema 'services/treasury/transfer_gold/arguments'
  result_schema 'services/treasury/transfer_gold/result'
end
```

## Why schemas help

| Benefit | Practical effect |
| --- | --- |
| Early failure | Invalid input never reaches business logic |
| Contract visibility | Callers can understand what the service expects |
| Safer integrations | Controllers, jobs, and other services can trust the shape |
| Better testing | Example data can be derived from schema definitions |

## A note on production conventions

Some codebases introduce a higher-level convention such as `schema_key` to centralize schema naming. That can be a useful overlay, but it should be understood as a convention layered on top of Servus rather than the framework's baseline explanation.
