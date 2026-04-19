# Production Testing Conventions

ZAR Core's testing conventions turn Servus from a useful framework into a highly disciplined service layer. The value of documenting those conventions is not to imply that Servus is incomplete without them. The value is to show how a production codebase keeps services reliable at scale.

## What the production conventions emphasize

| Emphasis | Why it helps |
| --- | --- |
| Test the named business action directly | Service boundaries stay first-class |
| Cover failure paths as deliberately as success paths | Domain rules remain explicit |
| Use schema examples where possible | Contracts stay synchronized with tests |
| Test emitted events and handler reactions separately | Side effects remain refactor-friendly |
| Keep controller tests thinner once service tests are strong | The application gets a cleaner testing pyramid |

## Practical takeaway

A team can adopt these conventions gradually. The important part is to understand which layer is being adopted: first the Servus framework contract, then the stronger discipline used by ZAR in production.
