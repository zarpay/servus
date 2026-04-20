# Async Execution

`.call_async` enqueues a service through ActiveJob. The service runs the same lifecycle — validation, logging, events — the only difference is when and where.

## Basic usage

```ruby
Treasury::TransferGold::Service.call_async(
  from_account: crown_account.id,
  to_account: night_watch_account.id,
  gold_dragons: 50
)
```

The service is enqueued immediately and executed by a worker. There is no return value — the service hasn't run yet.

## Queue and scheduling options

Pass ActiveJob options alongside the service arguments — Servus extracts them before passing the rest to your service:

```ruby
Treasury::TransferGold::Service.call_async(
  from_account: 1,
  to_account: 2,
  gold_dragons: 50,
  queue: :critical,
  priority: 10,
  wait: 5.minutes
)
```

| Option | What it does |
| --- | --- |
| `queue:` | Route to a specific queue (e.g., `:critical`, `:low_priority`) |
| `priority:` | Set job priority (adapter-dependent) |
| `wait:` | Delay execution by a duration (e.g., `5.minutes`) |
| `wait_until:` | Schedule execution for a specific time |

These are the same options `ActiveJob::Base.set` supports. They can also be nested under `job_options:` if you prefer:

```ruby
Treasury::TransferGold::Service.call_async(
  from_account: 1,
  to_account: 2,
  gold_dragons: 50,
  job_options: { queue: :critical, priority: 10, wait: 5.minutes }
)
```

## Arguments must be serializable

ActiveJob serializes arguments, so service arguments must be primitives (strings, integers, booleans), hashes, and arrays. Pass IDs instead of ActiveRecord instances:

```ruby
# Works — IDs and primitives
Treasury::TransferGold::Service.call_async(
  from_account: crown_account.id,
  to_account: night_watch_account.id,
  gold_dragons: 50
)

# Won't serialize reliably — pass the ID instead
Treasury::TransferGold::Service.call_async(
  from_account: crown_account,
  to_account: night_watch_account,
  gold_dragons: 50
)
```

::: tip lazily resolvers
This is where [`lazily`](/features/lazy-resolvers) helps. Declare `lazily :from_account, finds: Account` and the service accepts either an instance (sync) or an ID (async) — same code, both paths.
:::

## One service, both paths

The service itself doesn't know or care whether it was called synchronously or asynchronously. There's no `if async?` branching, no separate job class with its own logic, no risk of the two paths drifting apart. The business logic lives in one place and runs the same way regardless of how it was invoked.

This means you can develop and test a service synchronously — fast feedback, easy debugging — and then switch a call site to `.call_async` when you're ready to move it to the background. Nothing inside the service changes.

## How it works

`call_async` enqueues a `Servus::Extensions::Async::Job` that stores the service class name and arguments. When the worker picks it up, it calls `Service.call(**args)` — the full lifecycle runs exactly as if you had called `.call` directly.

```ruby
args = { from_account: 1, to_account: 2, gold_dragons: 50 }

# These two are functionally identical — the second just runs later
Treasury::TransferGold::Service.call(**args)
Treasury::TransferGold::Service.call_async(**args)
```

## Error behavior

Business failures (`failure(...)`) don't trigger ActiveJob retries — the job completes successfully, it just returns a failure `Response`. Since there's no caller waiting for the response, failures are visible through logs and events.

System exceptions (uncaught errors) trigger ActiveJob's retry mechanism as usual. Use `rescue_from` to convert transient exceptions into failures if you don't want retries:

```ruby
class Service < Servus::Base
  # This will retry via ActiveJob
  # rescue_from is NOT defined for Net::HTTPError

  # This will NOT retry — converted to a failure Response
  rescue_from Timeout::Error, use: ServiceUnavailableError
end
```