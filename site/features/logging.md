# Logging

Logging is one of the quieter strengths of Servus. Because the framework already owns the service boundary, it can log execution consistently without forcing every service author to invent a logging pattern from scratch.

## What gets logged

| Concern | Why it matters |
| --- | --- |
| Service name | Helps readers identify the business action that ran |
| Arguments | Helps explain what was attempted, when safe to log |
| Outcome | Makes success and failure paths visible |
| Timing | Surfaces slow services for investigation |

## Operational value

A consistent service boundary makes production debugging easier. Instead of searching through a mix of controller logs, model logs, and bespoke instrumentation, teams can reason in terms of named business actions.

## Sensitive data

Logging should still be selective. Payment credentials, personal identifiers, or other sensitive material should be filtered or omitted. Servus makes logging easier, but it does not remove the responsibility to log thoughtfully.
