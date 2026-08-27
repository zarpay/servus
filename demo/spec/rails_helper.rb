# frozen_string_literal: true

# =============================================================================
# rails_helper.rb — Rails-aware additions to spec_helper
# =============================================================================
#
# Required only by specs that need Rails, ActiveRecord, or Servus's test
# helpers. Specs covering plain-Ruby behaviour stay on `require "spec_helper"`.
#
# Notable wiring:
#
#   - `require "servus/testing"` brings in every matcher Servus ships
#     (emit_event, call_service, have_schema, be_service_success,
#     be_service_failure, be_guard_failure). They self-register on
#     RSpec::Matchers, so no `config.include` is needed for them.
#
#   - `Servus::Testing::ExampleBuilders` DOES need including — it provides
#     `servus_arguments_example`, `servus_result_example`, and friends, which
#     build fixtures out of the `example:` keys in a service's own schema.
#
#   - `spec/support/**` carries the isolation helpers: schema registry
#     snapshotting and the ActiveJob adapter tag.

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "servus/testing"

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join("spec/fixtures")]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include Servus::Testing::ExampleBuilders
end
