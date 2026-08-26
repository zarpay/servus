# Configuration

Servus works without any configuration. All settings have sensible defaults. When you need to customize, create an initializer:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|

  # ── Directory Settings ──────────────────────────────────────────────
  # Controls where Servus looks for Event classes, guards, and services.
  # These paths are relative to Rails.root. Generators also use these
  # paths when creating new files.

  config.services_dir = "app/services"  # default: "app/services"
  config.events_dir   = "app/events"    # default: "app/events"
  config.guards_dir   = "app/guards"    # default: "app/guards"
  config.tests_dir    = "spec"          # default: "spec"

  # ── Routers ────────────────────────────────────────────────────────
  # Ordered list of routers that resolve service invocations for events.
  # The Bus iterates in order, deduplicates by key, and executes.
  # Defaults to [Servus::Events::ClassRouter.new] which reads invoke
  # declarations from Event classes.

  config.routers = [
    Servus::Events::ClassRouter.new,
    # MyApp::DataDrivenRouter.new
  ]

  # ── Guards ──────────────────────────────────────────────────────────
  # Servus includes four built-in guards: PresenceGuard, TruthyGuard,
  # FalseyGuard, and StateGuard. Set to false if you want to disable
  # them entirely (your custom guards still load from guards_dir).

  config.include_default_guards = true  # default: true

  # ── Log Filtering ───────────────────────────────────────────────────
  # Filters sensitive argument values out of Servus's service-call log
  # lines (shown as [FILTERED]). Accepts the same notations as
  # ActiveSupport::ParameterFilter: partial-match strings/symbols,
  # regexps, and procs. Defaults to [] (no filtering).
  # Rails users can simply reuse their app's request-log filtering:
  # config.log_filter_parameters = Rails.application.config.filter_parameters

  config.log_filter_parameters = [                                    # default: []
    :passw, :email, :secret, :token, :_key, :crypt, :salt,
    :certificate, :otp, :ssn, :cvv, :cvc
  ]

  # ── Schema Enforcement ─────────────────────────────────────────────
  # When true, Servus raises SchemaRequiredError if a service or Event
  # class is used without the corresponding schema defined. Useful for
  # teams that want to enforce schemas across all services.

  config.require_service_arguments_schema = false  # default: false
  config.require_service_result_schema    = false  # default: false
  config.require_event_payload_schema     = false  # default: false
end
```
