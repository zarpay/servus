## [Unreleased]

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
- Added: Test helpers (`servus_arguments_example` and `servus_result_example`) to extract example values from schemas for testing
- Added: YARD documentation configuration with README homepage and markdown file support
- Added: Added `schema` DSL method for cleaner schema definition. Supports `schema arguments: {...}, result: {...}` syntax. Fully backwards compatible with existing `ARGUMENTS_SCHEMA` and `RESULT_SCHEMA` constants.
- Added: Added support from blocks on `rescue_from` to override default failure handler.
- Fixed: YARD link resolution warnings in documentation

## [0.1.3] - 2025-10-10
- Added: Added `call_async` method to `Servus::Base` to enqueue a job for calling the service asynchronously
- Added: Added `Async::Job` to handle async enqueing with support for ActiveJob set options

## [0.1.1] - 2025-08-20

- Added: Added `rescue_from` method to `Servus::Base` to rescue from standard errors and use custom error types.
- Added: Added `run_service` and `render_service_object_error` helpers to `Servus::Helpers::ControllerHelpers`.
- Fixed: All rubocop warnings.

## [0.1.0] - 2025-04-28

- Initial release
