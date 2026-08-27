# frozen_string_literal: true

# =============================================================================
# Servus configuration and schema registry
# =============================================================================
#
# This file is the gem's configuration surface. It does two jobs:
#
#   1. Sets every option on `Servus.config`, with a note on what each one does.
#   2. Registers the shared schema fragments that services reference by `$ref`.
#
# Read this first — every other file in the app assumes what is set here.
#
# ---------------------------------------------------------------------------
# A trap worth knowing about
# ---------------------------------------------------------------------------
#
# `config.include_default_guards` is read at *require* time, inside the gem's
# own `guards.rb`, not when you assign it. By the time an initializer runs,
# `require "servus"` has already happened and the built-in guards are already
# loaded. Setting it to false here would have no effect.
#
# To actually disable the built-ins you would need to set it before the gem is
# required — e.g. in `config/application.rb` before `Bundler.require`. This demo
# leaves them on, which is the default and what almost every app wants.

require Rails.root.join("config/schemas/westeros")

Servus.configure do |config|
  # ---------------------------------------------------------------------------
  # Directory settings
  # ---------------------------------------------------------------------------
  #
  # These do two different jobs, which is easy to miss:
  #
  #   - `events_dir` and `guards_dir` are eager-required by the railtie on every
  #     boot and reload. Event classes must live under `events_dir` matching
  #     `*_event.rb` or they never register with the Bus; guards must live under
  #     `guards_dir` matching `*_guard.rb` or their `enforce_*!` methods are
  #     never defined.
  #   - `services_dir` and `tests_dir` are used only by the generators. Services
  #     are autoloaded by Rails like any other class.
  config.services_dir = "app/services"
  config.events_dir   = "app/events"
  config.guards_dir   = "app/guards"
  config.tests_dir    = "spec"

  # ---------------------------------------------------------------------------
  # Schema enforcement
  # ---------------------------------------------------------------------------
  #
  # All three default to false. This demo turns on arguments and payload
  # enforcement so that a service or event without a contract fails loudly
  # rather than silently validating nothing — which is the whole argument
  # behind Servus 1.0's inline-only schemas.
  #
  # `require_service_result_schema` is deliberately left OFF so the harness can
  # also demonstrate a service that returns unvalidated data (see
  # `Citadel::ConsultRecords::Service`). Turning all three on is the stricter
  # posture most production apps should adopt.
  config.require_service_arguments_schema = true
  config.require_service_result_schema    = false
  config.require_event_payload_schema     = true

  # ---------------------------------------------------------------------------
  # Lockdown
  # ---------------------------------------------------------------------------
  #
  # When true (the default), `.new` is private on every service and instance
  # `#call` is privatised automatically. Callers must go through `.call`, which
  # is what runs validation, logging, benchmarking, guards, and event emission.
  #
  # Bypassing it would skip all of that silently, so the gem makes it
  # impossible rather than merely discouraged.
  config.lockdown_enabled = true

  # ---------------------------------------------------------------------------
  # Log filtering
  # ---------------------------------------------------------------------------
  #
  # Servus logs every service call with its arguments. Anything matching these
  # patterns is rendered as `[FILTERED]`. Reusing Rails' own request-log
  # filtering keeps one list rather than two.
  #
  # Note this covers *service arguments* only — event payloads are not filtered.
  config.log_filter_parameters = Rails.application.config.filter_parameters

  # ---------------------------------------------------------------------------
  # Routers
  # ---------------------------------------------------------------------------
  #
  # The Bus asks each router in order for invocations, then deduplicates by
  # identity. `ClassRouter` is the default and reads `enqueue` declarations off
  # Event classes. `RavenRosterRouter` is a custom router this app adds to show
  # that routing is an extension point — see app/routers/raven_roster_router.rb.
  #
  # Assigned in `to_prepare` rather than here because the custom router is an
  # autoloaded constant, and holding a reference to it across a reload would
  # keep a stale class alive.
end

Rails.application.config.to_prepare do
  Servus.config.routers = [
    Servus::Events::ClassRouter.new,
    RavenRosterRouter.new
  ]

  # ---------------------------------------------------------------------------
  # Shared schema fragments
  # ---------------------------------------------------------------------------
  #
  # Registered under short keys that services reference as
  # `{ '$ref' => '#/core/$defs/gold_dragons' }`.
  #
  # Registering the same key with an identical value is a no-op, so running
  # this on every reload is safe. Registering a *different* value logs a
  # warning and rebuilds every compiled schema that referenced it.
  Servus::Schema.register("core", WesterosSchemas::CORE)
  Servus::Schema.register("houses", WesterosSchemas::HOUSES)
end
