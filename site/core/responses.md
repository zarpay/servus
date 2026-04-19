# Responses

Every Servus call returns a response object. That choice removes a large amount of ambiguity because callers always know how to inspect the outcome of a service.

## Response shape

| Property | Success response | Failure response |
| --- | --- | --- |
| `success?` | `true` | `false` |
| `data` | Structured result payload | Usually `nil`, though failure data may be present |
| `error` | `nil` | A `Servus::Support::Errors::*` object |
| `error.message` | Not applicable | Human-readable reason |
| `error.api_error` | Not applicable | API-friendly error representation |

## The three response helpers

| Helper | Use |
| --- | --- |
| `success(data)` | Return a successful outcome with structured data |
| `failure(message, **options)` | Return an expected business failure |
| `error!(message, **options)` | Raise for exceptional situations that should halt execution |

## Access patterns

```ruby
result = Ravens::DispatchMessage::Service.call(
  origin: king_landing_rookery,
  destination: castle_black,
  message: 'Supplies arrive at dawn'
)

if result.success?
  puts result.data[:dispatch_id]
else
  warn result.error.message
end
```

## A practical rule for composition

If a downstream service fails and the calling service has no better domain language to add, return that response unchanged. Servus responses are useful precisely because they can travel through a workflow without constant re-wrapping.
