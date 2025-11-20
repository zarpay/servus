## [Unreleased]

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
