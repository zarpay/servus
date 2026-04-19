# Adoption Path

A team does not need to adopt every Servus capability or every ZAR-style convention on the first day. In practice, adoption is usually smoother when the framework is introduced in layers.

## A practical sequence

| Stage | What to adopt | Why it is a good moment |
| --- | --- | --- |
| 1 | Plain services with `.call`, `call`, and response objects | The team learns the framework boundary without too much ceremony |
| 2 | Explicit success and failure tests | The service contract becomes dependable quickly |
| 3 | Schemas, guards, and events where they clearly help | The framework features begin paying for themselves in shared workflows |
| 4 | `call_async` for background execution | Async work can reuse the same business boundary |
| 5 | Opinionated production conventions such as `option` and `schema_key` | These conventions become worthwhile once the service layer is large enough to benefit from stricter uniformity |

## Why this ordering works

The main risk in adopting Servus is not technical complexity. The main risk is conflating the framework itself with the most opinionated patterns used by one mature production codebase. This sequencing avoids that confusion. Teams first learn the Servus model, then decide which stronger conventions improve readability and consistency in their own environment.

## A useful decision rule

When introducing a new convention, ask whether it clarifies the framework boundary or obscures it. A good convention makes the service layer easier to scan and easier to test. A poor convention makes new users think they must first memorize house style before they can understand Servus.
