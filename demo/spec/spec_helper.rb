# frozen_string_literal: true

# =============================================================================
# spec_helper.rb — configuration shared by every spec
# =============================================================================
#
# Loaded automatically via `--require spec_helper` in `.rspec`.
#
# Keep this file Rails-free. Anything needing ActiveRecord, the models, or the
# Rails-only parts of Servus belongs in `rails_helper.rb`.
#
# That split is not just tidiness — a good chunk of Servus works in plain Ruby
# (services, schemas, guards, the event bus, `rescue_from`), and specs that
# require only this file *prove* it. If one of those specs ever needs
# `rails_helper`, something that used to work outside Rails no longer does.

require "simplecov"
SimpleCov.start "rails" do
  skip %r{^/config/}
  skip %r{^/spec/}
  group "Services", "app/services"
  group "Events",   "app/events"
  group "Guards",   "app/guards"
  group "Routers",  "app/routers"
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior     = :apply_to_host_groups
  config.filter_run_when_matching             :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # A single example often needs to assert several facets of one behaviour —
  # a Response's success flag AND its data AND the event it emitted. Turning
  # aggregate_failures on by default means all mismatches are reported in one
  # run rather than one per re-run.
  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true unless meta.key?(:aggregate_failures)
  end
end
