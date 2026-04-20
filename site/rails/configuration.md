# Configuration

Servus works without any configuration. All settings have sensible defaults. When you need to customize, create an initializer:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|

  # ── Directory Settings ──────────────────────────────────────────────
  # Controls where Servus looks for file-based schemas, event handlers,
  # guards, and services. These paths are relative to Rails.root.
  # Generators also use these paths when creating new files.

  config.services_dir = "app/services"  # default: "app/services"
  config.schemas_dir  = "app/schemas"   # default: "app/schemas"
  config.events_dir   = "app/events"    # default: "app/events"
  config.guards_dir   = "app/guards"    # default: "app/guards"
  config.tests_dir    = "spec"          # default: "spec"

  # ── Event Validation ────────────────────────────────────────────────
  # When true, Servus.validate_all_handlers! raises OrphanedHandlerError
  # if any handler subscribes to an event that no service emits.
  # Useful in CI or a boot-time rake task to catch typos and stale handlers.

  config.strict_event_validation = true  # default: true

  # ── Guards ──────────────────────────────────────────────────────────
  # Servus includes four built-in guards: PresenceGuard, TruthyGuard,
  # FalseyGuard, and StateGuard. Set to false if you want to disable
  # them entirely (your custom guards still load from guards_dir).

  config.include_default_guards = true  # default: true
end
```

All seven options are `attr_accessor` — read them with `Servus.config.schemas_dir` and write them in the `configure` block.