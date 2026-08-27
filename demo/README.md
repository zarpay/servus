# servus demo — an annotated Rails harness

> **You are reading the demo package readme.** This Rails app lives inside the
> `zarpay/servus` repository as a sibling of [`gem/`](../gem) and
> [`site/`](../site). See the [root README](../README.md) for the layout.

A Rails 8.1 application whose only purpose is to exercise every public feature
of the [`servus`](../gem) gem in realistic use. Every file is annotated as a
textbook, so the app can be read to learn the library in context rather than in
isolation.

## Why this exists

Three audiences at once:

1. **Library users** — the four domains below show idiomatic patterns for each
   feature, with inline commentary explaining *why* each choice was made and
   what it costs.
2. **Library contributors** — `bundle exec rspec` here runs an integration
   suite against `../gem`. If a change to the gem regresses documented
   behaviour, this breaks.
3. **The gem author** — building the harness surfaced six real findings in the
   gem, listed at the bottom.

## Run it

```bash
bundle install
bin/rails db:migrate RAILS_ENV=test
bundle exec rspec
```

Current state: **200 examples, 0 failures**, 95% line coverage.

The Gemfile path-pins `gem "servus", path: "../gem"`, so the demo always tests
against the in-tree source. A change in `../gem` takes effect here immediately.

## How to read this app

Each file opens with a header naming what it teaches. Read in this order — each
step builds on the last.

| # | File | What it teaches |
|---|---|---|
| 1 | `config/initializers/servus.rb` | Every config option and what it does. Registers the shared schema fragments. Start here — everything else assumes it. |
| 2 | `config/schemas/westeros.rb` | Reusable schema fragments, and why they live in `config/` rather than `app/` or `lib/` |
| 3 | `app/services/application_service.rb` | An abstract base: schema inheritance, and `rescue_from` in both its forms |
| 4 | `app/guards/sufficient_gold_guard.rb` | A custom guard: `http_status`, `error_code`, a message template with a data block |
| 5 | `app/guards/loyal_house_guard.rb` | A guard whose message comes from I18n via `MessageResolver` |
| 6 | `app/services/treasury/transfer_gold/service.rb` | The flagship. Schemas with `$ref`, sibling-merge override, three guards, all three emission triggers, the `async` DSL |
| 7 | `app/services/ledger/record_entry/service.rb` | `lazily` resolvers, nested result data, a failure carrying structured `data:` |
| 8 | `app/services/citadel/summon_maester/service.rb` | `lazily` by a natural key and with an Array; `success(nil)` |
| 9 | `app/services/citadel/consult_records/service.rb` | A service with no result schema, and what that costs |
| 10 | `app/services/ravens/dispatch_message/service.rb` | A service built to be enqueued; `error!` |
| 11 | `app/events/gold_transferred_event.rb` | Payload schemas, multiple reactions, scheduling options, conditional reactions |
| 12 | `app/events/raven_requested_event.rb` | The pass-through reaction form, and `Event.emit` without a service |
| 13 | `app/events/large_transfer_event.rb` | Why an event's payload describes the event, not its reaction |
| 14 | `app/routers/raven_roster_router.rb` | Routing as an extension point, and invocation deduplication |
| 15 | `app/controllers/treasury/transfers_controller.rb` | `run_service` and the default error envelope |
| 16 | `app/controllers/citadel/records_controller.rb` | Overriding `render_service_error` |
| 17 | `spec/spec_helper.rb` / `spec/rails_helper.rb` | The Rails-free / Rails-aware split, and wiring Servus's test helpers |
| 18 | `spec/support/*.rb` | Schema-registry isolation and the ActiveJob adapter tag |
| 19 | `spec/matchers/servus_matchers_spec.rb` | Every matcher and every chain; all six example builders |
| 20 | `spec/integration/treasury_transfer_spec.rb` | One transfer, HTTP request to background reaction — the argument for the library |

## The four domains

Each owns a cluster of features, and each is deliberately asymmetric in one
respect so both shapes of a feature get covered.

| Domain | Models | Owns |
|---|---|---|
| **Treasury** | `Vault` | The flagship path. Full schema DSL, three guards, all emission triggers, `async`, `run_service` |
| **Ravens** | `Raven` | Reactions. Enqueued work, scheduling options, `error!` |
| **Ledger** | `LedgerEntry` | Records. `lazily`, nested `DataObject` access, structured failures |
| **Citadel** | `House` | Edges. No result schema, custom error envelope, `success(nil)` |

## Feature coverage

| Feature | Demonstrated in | Proven by |
|---|---|---|
| `.call`, `success`, `failure`, `error!` | all services | `spec/services/**` |
| `Response`, `DataObject` nesting | `ledger/record_entry` | `spec/services/ledger/record_entry_spec.rb` |
| Lockdown (`.new` is private) | — | `spec/config/servus_config_spec.rb` |
| `rescue_from`, both forms | `application_service.rb` | `spec/services/treasury/transfer_gold_spec.rb` |
| `schema` DSL, all four kinds | every service and event | `spec/services/**`, `spec/matchers/**` |
| Schema inheritance | `application_service.rb` | `spec/services/treasury/transfer_gold_spec.rb` |
| Schema registry, `$ref`, sibling merge | `config/schemas/westeros.rb` | `spec/schemas/registry_spec.rb` |
| Every schema error class | — | `spec/schemas/registry_spec.rb` |
| Four built-in guards | `treasury/transfer_gold` | `spec/guards/builtin_guards_spec.rb` |
| Custom guards, both message forms | `app/guards/*` | `spec/guards/custom_guards_spec.rb` |
| `Guard.execute!` / `execute?` | — | `spec/guards/custom_guards_spec.rb` |
| `emits`, all triggers and builders | `treasury/transfer_gold` | `spec/events/emission_spec.rb` |
| Conditional and multiple emission | `treasury/transfer_gold` | `spec/events/emission_spec.rb` |
| `enqueue`, scheduling, conditions | `app/events/*` | `spec/events/reactions_spec.rb` |
| `Event.emit` / `.handle` | `raven_requested_event` | `spec/events/reactions_spec.rb` |
| Custom router, invocation dedup | `raven_roster_router.rb` | `spec/events/reactions_spec.rb` |
| `Bus.subscribe_all` | — | `spec/events/reactions_spec.rb` |
| `.call_async`, `async` DSL, named jobs | `treasury`, `ravens` | `spec/async/call_async_spec.rb` |
| `lazily`, all three shapes | `ledger`, `citadel` | `spec/services/**` |
| `run_service`, `render_service_error` | `app/controllers/*` | `spec/requests/**` |
| Error classes → HTTP status | `app/controllers/*` | `spec/requests/**` |
| Every config option | `config/initializers/servus.rb` | `spec/config/servus_config_spec.rb` |
| Every matcher and example builder | — | `spec/matchers/servus_matchers_spec.rb` |
| Logging and parameter filtering | — | `spec/logging/service_logging_spec.rb` |

## Generators

Not exercised by the suite, but available:

```bash
bin/rails g servus:service treasury/settle_ledger vault_id amount
bin/rails g servus:event ledger_settled
bin/rails g servus:guard vault_unsealed
```

They honour `config.services_dir`, `events_dir`, `guards_dir`, and `tests_dir`.
Pass `--no-docs` to skip the YARD and TODO scaffolding.

> **Note:** the service generator's *spec* template is stale — it references
> `Servus::ServiceJob`, `Servus::Testing::EventHelpers`, and
> `servus_expect_event(...)`, none of which exist. The service file it
> generates is correct; the spec file needs rewriting by hand.

## Traps this app documents

Things that cost real time to work out, each explained where it bites:

| Trap | Where |
|---|---|
| The `async` DSL is undefined in development — `ActiveJob::Base` is lazily autoloaded, so the railtie's `on_load` hook has not fired when a service class body runs. Works in production and under RSpec, fails in console and runner. | `config/initializers/servus.rb` |
| Schema fragments must not live in an autoloaded path. Refs are strings, so nothing references the constant, so Zeitwerk never loads the file. | `config/schemas/westeros.rb` |
| `ensure_registered!` does not strip the `Event` suffix: `GoldTransferredEvent` infers `:gold_transferred_event`. | `app/events/gold_transferred_event.rb` |
| A generated `ServiceJob` constant is not a file — it only exists once its service has loaded. | `spec/async/call_async_spec.rb` |
| `call_async` silently eats a service argument named `queue`, `wait`, `wait_until`, `priority`, or `job_options`. | `spec/async/call_async_spec.rb` |
| `Guard#method_missing` falls through to `super` for falsey kwargs, so a nil argument raises `NameError`. | `app/guards/sufficient_gold_guard.rb` |
| A `GuardError`'s `http_status` is whatever the guard declared — the built-ins use the integer `422`, not the Rack symbol. | `spec/guards/builtin_guards_spec.rb` |
| A service returning nil instead of a `Response` fails inside Servus's logger, blaming the wrong file. | `spec/matchers/servus_matchers_spec.rb` |
| `call_service(...).with(...)` on an async call must include the scheduling options. | `spec/matchers/servus_matchers_spec.rb` |
| The `:inline` adapter cannot schedule a future job, so any reaction with `wait:` needs `:test` plus `perform_enqueued_jobs`. | `spec/support/active_job.rb` |
| Event payloads are **not** parameter-filtered, unlike service arguments. | `spec/logging/service_logging_spec.rb` |

## What Servus needs, and what it does not

| Feature | Requires |
|---|---|
| Services, schemas, guards, `rescue_from`, the event bus | Plain Ruby |
| `.call_async`, the `async` DSL, **any event `enqueue`** | ActiveJob |
| `lazily` | ActiveRecord |
| `run_service`, `render_service_error`, generators | Rails |

Since 1.0 event invocation is always asynchronous, so an Event class that
declares `enqueue` needs ActiveJob. Servus's core does not.
