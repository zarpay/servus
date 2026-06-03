## [Unreleased]

### Added

- **`Servus::Result` as a top-level primary concern**: The result object is now exposed
  at `Servus::Result` and is usable from any code, not just inside a service. New class-method
  factories mirror the `Servus::Base` DSL:

  ```ruby
  Servus::Result.success(user_id: 1)
  Servus::Result.failure("Card declined", type: Servus::Support::Errors::BadRequestError)
  Servus::Result.failure("Declined", data: { reason: "insufficient_funds" })
  ```

  `Servus::Base#success` and `#failure` now delegate to `Servus::Result.success` / `.failure`,
  giving a single source of truth for result construction. `Servus::Support::Response` remains
  as a silent alias of `Servus::Result` — existing code referencing the old constant continues
  to work unchanged.

## [0.5.2] - 2026-05-25

### Fixed

- **Proc/block context in `emits`**: Payload builder blocks and `if:`/`unless:` condition procs now
  execute bound to the service instance via `instance_exec`, matching the behaviour of Symbol method
  references. Previously, `builder.call(result)` left `self` as the class, so instance variables set
  during `#call` (e.g. `@my_flag`) were silently unreadable inside a block or lambda. Both forms now
  behave identically — `self` is always the service instance.

## [0.5.1] - 2026-05-25

### Added

- **Conditional emission on `emits`**: The `emits` macro now accepts `if:` and `unless:` options
  to gate whether an event fires at runtime. When the condition is not met, the event is completely
  skipped — no payload is built, no validation runs, and nothing reaches the bus. Both options accept
  a lambda/proc (receives the `result` object) or a Symbol naming a private instance method.
  Fully backwards compatible — existing `emits` declarations without conditions are unaffected.

  ```ruby
  emits :large_transfer_event, on: :success, if: ->(result) { result.data[:transferred] > 100 }
  emits :standard_transfer_event, on: :success, unless: ->(result) { result.data[:transferred] > 100 }
  emits :vip_transfer_event, on: :success, if: :vip_sender?
  ```

- **`failure_message_when_negated` on `emit_event` matcher**: `expect { }.not_to emit_event(:name)`
  now produces a clear failure message when the event was unexpectedly emitted.

- **`with:` option moved to `**options`**: The `emits` macro signature is now
  `emits(event_name, on:, **options, &block)` — `with:`, `if:`, and `unless:` are all uniform
  keyword options. No change to calling code; `emits :name, on: :success, with: :method` still works.

## [0.5.0] - 2026-05-07

### Breaking Changes

- **`Servus::EventHandler` removed** — use `Servus::Event`. The class represents the event itself,
  not a handler. Event classes serve three purposes: contract (name), validator (schema), and
  optional declarative routing (invoke declarations).
- **`handles :event_name` removed** — use `event_name :name`, or omit it entirely to infer the
  name from the class (e.g. `OrderPlaced` → `:order_placed`). Inference is triggered by
  `ensure_registered!` at boot time via the Railtie.
- **`Bus.register_handler` / `Bus.handlers_for` removed** — replaced by `Bus.register_event`
  (single Event per name) and `Bus.event_for` (returns one class, not an array).
- **`Bus.emit` now delegates through configurable routers** — instead of dispatching via
  ActiveSupport::Notifications handler subscriptions, the Bus iterates `config.routers`,
  collects Invocation objects, deduplicates by key (first wins), and executes.
  ActiveSupport::Notifications is still used to wrap dispatch for `subscribe_all`.
- **`validate_all_handlers!` removed** — the ObjectSpace-scanning validation added complexity
  for little value. Orphaned events surface quickly at runtime.
- **`strict_event_validation` config removed** — no longer applicable without `validate_all_handlers!`.
- **`OrphanedHandlerError` removed** — no longer raised by anything.
- **`invoke` block now optional** — omitting the block passes the full payload as params.
- **Generator `servus:event_handler` replaced by `servus:event`** — generates `app/events/name.rb`
  (no `_handler` suffix), class inherits from `ApplicationEvent`, event name inferred.
- **Railtie loads `**/*.rb` from events_dir** — instead of `**/*_handler.rb`.

### Added

- **`Servus::Events::Router`** — abstract base class for event routers. Implement `#resolve(event_name, payload)`
  to return an array of `Invocation` objects.
- **`Servus::Events::ClassRouter`** — default router that reads `invoke` declarations from Event classes.
  Ships as the default when no routers are configured.
- **`Servus::Events::Invocation`** — value object representing a resolved service call. Attributes:
  `service`, `params`, `options`. Methods: `#execute` (sync or async), `#key` (SHA-256 dedup key).
- **`config.routers`** — ordered array of routers. Defaults to `[ClassRouter.new]`. The Bus iterates
  in order, deduplicates invocations by key, and executes.
- **`Event.invocations_for(payload)`** — returns `Invocation` objects with conditions already evaluated.
  This is what routers call to resolve actions from Event class declarations.
- **`Event.ensure_registered!`** — infers event name from class name and registers with the Bus.
  Called automatically by the Railtie after loading event files.

## [0.4.0] - 2026-04-30

### Breaking Changes

- **`Guard#test` is now zero-arg**: Subclasses of `Servus::Guard` must define `test` without arguments,
  reading call arguments via `method_missing` on the instance (e.g., `amount` rather than receiving
  `amount:` as a kwarg). Previously, `execute!` passed the same kwargs to both `new` and `test`, which
  was redundant since `initialize` already stores them as `@kwargs`. Guards with `def test(**)` or
  `def test(foo:)` signatures must be updated — the scaffold generator and built-in guards
  (`Presence`, `Truthy`, `Falsey`, `State`) have all been updated to the new pattern.
- **Event payload validation on emits DSL**: Payload schemas are now validated when events are
  emitted via the `emits` DSL, not just via `Handler.emit`. Services emitting payloads that don't
  match handler schemas will now raise `ValidationError`.

### Added

- **Service invocation lockdown**: `Servus::Base` now privatizes `.new` and any instance-level
  `#call` so services must be invoked through the class-level `.call` pipeline. This guarantees
  argument validation, logging, benchmarking, guards, result validation, and event emission are
  never silently skipped by calling `MyService.new.call` directly. Enabled by default; opt out
  with `Servus.configure { |c| c.lockdown_enabled = false }`. Implemented as
  `Servus::Support::Lockdown` and gated by a new `Servus::Config#lockdown_enabled` flag.
- **`call!` service composition helper**: Instance method on `Servus::Base`. Invokes a
  sub-service from within a service's `#call` and returns its data on success; on failure,
  halts the outer service with the sub-service's Response unchanged (same error object,
  message, code, http_status).
- **`run_service!` controller helper**: Bang counterpart to `run_service` on
  `Servus::Helpers::ControllerHelpers`. Stores the full Response in `@result` the same way
  `run_service` does, then returns the service's data on success or raises the failure's
  `ServiceError` otherwise — for paths where an exception is preferable to rendering a
  JSON error.
- **Schema enforcement config**: Three new config flags — `require_service_arguments_schema`,
  `require_service_result_schema`, and `require_event_payload_schema` — raise
  `SchemaRequiredError` when a service or handler is invoked without the corresponding schema.
  All default to `false`.
- **`SchemaRequiredError`**: New error class raised when schema enforcement is enabled and a
  schema is missing.
- **Response assertion matchers**: `be_service_success`, `be_service_failure(ErrorClass)`, and
  `be_guard_failure(code)` RSpec matchers with `.with_message` chaining for concise response
  assertions.
- **`have_schema` matcher**: RSpec matcher for asserting schema presence on services
  (`:arguments`, `:result`, `:failure`) and event handlers (`:payload`).
- **Response builder test helpers**: `servus_success_response(data)` and
  `servus_failure_response(message, data:, type:)` in `ExampleBuilders` for building mock
  responses without calling the constructor directly.
- **Guard failure logging**: Guard failures are now logged at `warn` level with the error message.
- **Event emission logging**: Event emissions are logged at `info` level with the event name and payload.
- **`Bus.subscribe_all`**: Subscribe to all Servus event emissions with a clean API. Yields
  `event_name` and `payload` as positional args, plus `started_at:`, `finished_at:`, and `id:`
  as keyword args.
- **`config.tests_dir`**: Configurable directory for generator spec output (default: `"spec"`).

## [0.3.0] - 2026-04-03

### Breaking Changes

- **Failure responses can now carry data**: `failure()` accepts an optional `data:` kwarg. Previously,
  `result.data` was guaranteed to be `nil` on failure. Code that checks `result.data` for truthiness
  to determine success/failure must switch to `result.success?` or `result.failure?`.
  See the [Failure response docs](site/core/responses.md) for details.
- **`Response#with_data` removed**: Replaced by the `data:` kwarg on `failure()`. The `with_data` method
  allowed arbitrary mutation of responses after creation, bypassing schema validation.

### Added

- **`lazily` resolver DSL**: Declare lazy record resolvers on services with `lazily :user, finds: User`.
  Accepts either an ID or an already-loaded instance — resolves on first access, memoizes the result.
  Supports custom columns (`by: :uuid`), array input (via `.where`), and dry-initializer compatibility.
  Loaded as an extension via Railtie when ActiveRecord is present.
- **Failure data support**: `failure()` accepts an optional `data:` keyword argument for attaching
  structured data to failure responses (e.g., `failure("Declined", data: { reason: "insufficient_funds" })`).
  Defaults to `nil` for backwards compatibility with services that don't use it.
- **Failure schema validation**: Define a `failure` schema via the `schema` DSL, `FAILURE_SCHEMA` constant,
  or `failure.json` file. When present, failure response data is validated against it — just like success
  results are validated against `result` schemas.
- **`servus_failure_example` test helper**: Extracts example values from a service's `failure` schema,
  returning a failure `Response` for use in tests.
- **`failure?` predicate on Response**: Complement to `success?` for cleaner conditional handling.
- **`DataObject` wrapper for response data**: Hash data returned by services is wrapped in a read-only
  `DataObject` that supports accessor-style access (`result.data.user.email`) alongside bracket access
  (`result.data[:user]`). Nested Hashes and Hashes inside Arrays are recursively wrapped. Non-Hash values
  (models, nil) pass through unwrapped.

## [0.2.1] - 2025-12-20

### Added

- **EventHandler Scheduling Options**: Extended the `invoke` DSL to support ActiveJob scheduling options
  - `:wait` - delay execution (e.g., `5.minutes`)
  - `:wait_until` - schedule for specific time
  - `:priority` - job priority
  - `:job_options` - additional ActiveJob options
  - Options are passed through to `call_async`, enabling delayed and scheduled event handling

- **Custom HTTP Error Classes**: Added granular error classes for HTTP status handling
  - Error classes for common HTTP statuses (400, 401, 403, 404, 409, 422, 429, 500, 502, 503, 504)
  - Each error class has appropriate `http_status` and default `code`/`message`
  - Enables more precise error handling and cleaner rescue blocks

## [0.2.0] - 2025-12-16

### Added

- **Guards System**: Reusable validation rules with rich error responses
  - `Servus::Guard` base class for creating custom guards
  - `Servus::Guards` module included in services with `enforce_*!` and `check_*?` methods
  - Built-in guards:
    - `PresenceGuard` - validates values are present (not nil or empty)
    - `TruthyGuard` - validates object attributes are truthy
    - `FalseyGuard` - validates object attributes are falsey
    - `StateGuard` - validates object attributes match expected value(s)
  - Guards auto-define methods when classes inherit from `Servus::Guard`
  - Guard DSL: `http_status`, `error_code`, `message` with interpolation support
  - Multiple message template formats: String, I18n Symbol, inline Hash, Proc
  - Rails auto-loading from `app/guards/*_guard.rb`
  - Configuration options: `guards_dir`, `include_default_guards`

- **GuardError**: New error class for guard validation failures
  - Custom `code` and `http_status` per guard
  - Services catch `:guard_failure` and wrap in failure response automatically

### Changed

- **Error API Refactored**: Cleaner separation of HTTP status and error body
  - All errors now have `http_status` method returning Rails status symbol
  - `api_error` returns `{ code:, message: }` for response body only
  - Follows community conventions (Stripe, JSON:API) where HTTP status is in header

- **Controller Helpers Refactored**:
  - Renamed `render_service_object_error` to `render_service_error`
  - Now takes error object directly instead of `api_error` hash
  - Response format: `{ error: { code:, message: } }` with status from `error.http_status`

### Breaking Changes

- `render_service_object_error` renamed to `render_service_error`
- `render_service_error` now accepts error object, not hash: `render_service_error(result.error)` instead of `render_service_error(result.error.api_error)`
- Error response JSON structure changed from `{ code:, message: }` to `{ error: { code:, message: } }`

## [0.1.6] - 2025-12-06

### Fixed

- Make `emit_events_for` public in `Servus::Events::Emitter` to allow external event emission

## [0.1.5] - 2025-12-03

### Added

- **Event Bus Architecture**: Introduced event-driven architecture for decoupling service logic from side effects
  - `Servus::EventHandler` base class for creating event handlers that subscribe to events and invoke services
  - `emits` DSL on `Servus::Base` for declaring events that fire on `:success`, `:failure`, or `:error!`
  - `Servus::Events::Bus` for routing events to handlers via ActiveSupport::Notifications
  - Rails generator: `rails g servus:event_handler event_name` creates handler and spec files
  - Event handlers auto-load from `app/events/` directory in Rails applications

- **Event Payload Validation**: JSON Schema validation for event payloads
  - `schema payload: {...}` DSL on EventHandler for declaring payload schemas
  - Validation occurs when events are emitted via `EventHandler.emit(payload)`

- **Event Testing Matchers**: RSpec matchers for testing event emission
  - `emit_event(:event_name)` matcher to assert events are emitted
  - `emit_event(:event_name).with(payload)` for payload assertions
  - `call_service(ServiceClass).with(args)` matcher for handler testing
  - `call_service(ServiceClass).async` for async invocation testing

- **Configuration Options**: New and updated configuration settings
  - `config.schemas_dir` - Directory for JSON schema files (default: `app/schemas`)
  - `config.services_dir` - Directory for service files (default: `app/services`)
  - `config.events_dir` - Directory for event handlers (default: `app/events`)
  - `config.strict_event_validation` - Validate handlers subscribe to emitted events (default: `true`)
  - `Servus::EventHandler.validate_all_handlers!` for CI validation of handler-event mappings

- **Generator Improvements**: Enhanced service and event handler generators
  - Service templates now include comprehensive YARD documentation
  - Service spec templates include example test patterns
  - JSON schema templates include proper structure with `$schema` reference
  - Event handler templates include full documentation and examples
  - `--no-docs` flag to skip documentation comments in generated files

### Changed

- Updated execution flow to include event emission after result validation
- Enhanced Railtie to auto-load event handlers and clear the event bus on reload in development

## [0.1.4] - 2025-11-21

### Added

- **Schema DSL method**: `schema arguments: {...}, result: {...}` syntax for cleaner schema definition.
  Fully backwards compatible with existing `ARGUMENTS_SCHEMA` and `RESULT_SCHEMA` constants.
- **Test helpers**: `servus_arguments_example` and `servus_result_example` for extracting example values
  from schemas in tests
- **`rescue_from` block support**: Override the default failure handler with a custom block
- **YARD documentation**: Configuration with README homepage and markdown file support

### Fixed

- YARD link resolution warnings in documentation

## [0.1.3] - 2025-10-10

### Added

- **`call_async`**: Enqueue service calls as background jobs via ActiveJob
- **`Async::Job`**: Job class for async enqueueing with support for ActiveJob `set` options

## [0.1.1] - 2025-08-20

### Added

- **`rescue_from`**: Rescue from standard errors and convert them to failure responses with custom error types
- **Controller helpers**: `run_service` and `render_service_object_error` in `Servus::Helpers::ControllerHelpers`

### Fixed

- All rubocop warnings

## [0.1.0] - 2025-04-28

- Initial release
