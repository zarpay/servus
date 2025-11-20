## [Unreleased]
- Added: Added support from blocks on `rescue_from` to override default failure handler.

## [0.1.3] - 2025-10-10
- Added: Added `call_async` method to `Servus::Base` to enqueue a job for calling the service asynchronously
- Added: Added `Async::Job` to handle async enqueing with support for ActiveJob set options

## [0.1.1] - 2025-08-20

- Added: Added `rescue_from` method to `Servus::Base` to rescue from standard errors and use custom error types.
- Added: Added `run_service` and `render_service_object_error` helpers to `Servus::Helpers::ControllerHelpers`.
- Fixed: All rubocop warnings.

## [0.1.0] - 2025-04-28

- Initial release
