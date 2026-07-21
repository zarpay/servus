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

## A named job per service

Servus generates a dedicated ActiveJob class for each service, named after it. For `Treasury::TransferGold::Service` the job is `Treasury::TransferGold::ServiceJob` — a sibling constant in the service's namespace. This means your background dashboard (Sidekiq, GoodJob, …) shows a meaningful, per-service job name instead of one generic class for every job in the system, so per-queue metrics, retries, and log filtering all line up with the service that actually ran.

You never write or reference these classes yourself — they're created for you when the service is defined.

## Per-service job configuration

Use the `async` class method to configure a service's job — queue, priority, retries, and anything else ActiveJob supports:

```ruby
class Treasury::TransferGold::Service < Servus::Base
  async queue: :critical, priority: 10

  async do
    retry_on Gringotts::Timeout, wait: 5.seconds, attempts: 3
    discard_on ActiveJob::DeserializationError
  end
end
```

`queue:` and `priority:` are keyword shortcuts for the two most common options. The block is evaluated in the job class's own context, so anything you'd normally write in an ActiveJob subclass — `retry_on`, `discard_on`, `around_perform`, and friends — works exactly as it does there.

These settings are the job's class-level defaults. Options passed inline to `call_async` are layered on top per enqueue, so an inline `queue:` still wins for that one call:

```ruby
# Runs on :critical by default (from the async block above)…
Treasury::TransferGold::Service.call_async(from_account: 1, to_account: 2, gold_dragons: 50)

# …but this one call is routed to :low_priority instead
Treasury::TransferGold::Service.call_async(
  from_account: 1,
  to_account: 2,
  gold_dragons: 50,
  queue: :low_priority
)
```

## How it works

`call_async` enqueues the service's named job with just the service arguments — the job class itself already identifies which service to run. When the worker picks it up, it calls `Service.call(**args)`, and the full lifecycle runs exactly as if you had called `.call` directly.

```ruby
args = { from_account: 1, to_account: 2, gold_dragons: 50 }

# These two are functionally identical — the second just runs later
Treasury::TransferGold::Service.call(**args)
Treasury::TransferGold::Service.call_async(**args)
```

::: warning Workers must eager-load
Because a job is serialized by its class name, the worker process has to be able to resolve that name. Servus defines each service's job when the service class loads, so under Rails' production eager-loading (the default) every job exists at boot. If you run workers with eager-loading off, make sure the service gets referenced before its jobs run.
:::

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