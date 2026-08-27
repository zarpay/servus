# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    enable_coverage :branch
    add_filter %r{^/spec/}
    track_files 'lib/**/*.rb'
  end
end

require 'servus'
require 'servus/testing'
require 'spec_support/active_job_loader'
require 'spec_support/schema_registry'
require 'spec_support/test_services'

# Internal tests sometimes instantiate anonymous Servus::Base subclasses to
# exercise instance-level behavior (guards, lazy resolvers) in isolation.
# Production code blocks `.new` and privatizes `#call`; disable the lockdown
# for the test suite. The lockdown itself is verified by
# spec/servus/base_lockdown_spec.rb, which re-enables it within its own scope.
Servus.config.lockdown_enabled = false

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Event invocation always enqueues, so a spec asserting that a service
  # actually ran needs the job to execute. Tag it `:inline_jobs` to swap the
  # adapter; everything else keeps `:test` and asserts on enqueued jobs.
  config.before(:each) do |example|
    ActiveJob::Base.queue_adapter = example.metadata[:inline_jobs] ? :inline : :test
  end
end
