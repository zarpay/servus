# Migration

Servus is often introduced into codebases that already contain large controllers, callback-heavy models, or background jobs with embedded business rules. A successful migration usually happens incrementally.

## Recommended path

| Step | Purpose |
| --- | --- |
| Name one business action | Give the migration a clear boundary |
| Extract a service without changing behavior | Preserve confidence while improving structure |
| Add explicit success and failure tests | Lock down the service contract |
| Introduce schemas, guards, or events only where they help | Keep the migration pragmatic |

## Migration rule of thumb

Do not try to make every extracted service maximally sophisticated on the first pass. First create the boundary. Then make that boundary more expressive as the framework features begin to pay for themselves.
