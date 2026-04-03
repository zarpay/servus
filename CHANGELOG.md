## [0.3.0] - 2026-04-03

### Breaking Changes

- **Failure responses can now carry data**: `failure()` accepts an optional `data:` kwarg. Previously,
  `result.data` was guaranteed to be `nil` on failure. Code that checks `result.data` for truthiness
  to determine success/failure must switch to `result.success?` or `result.failure?`.
  See the [Migration Guide](docs/guides/2_migration_guide.md#migrating-to-030) for details.
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
