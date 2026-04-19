# Controller Helpers Reference

Servus provides controller-oriented helpers so Rails applications can reduce boilerplate around invoking services and rendering failures.

| Helper | Purpose |
| --- | --- |
| `run_service` | Execute a service and centralize result handling |
| `render_service_error` | Render a failure response in a consistent shape |
| request validation helpers | Connect incoming HTTP data to the service contract |

These helpers are useful, but the main Servus controller pattern is still understandable without them: call the service, inspect the response, and render accordingly.
