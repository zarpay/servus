# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# Smoke spec — proves the harness itself is wired correctly
# =============================================================================
#
# Before any feature spec is worth trusting, four things must be true. If this
# file fails, nothing else in the suite means anything.
RSpec.describe "the demo harness" do
  it "loads Servus from the in-tree gem source" do
    expect(Servus::VERSION).to eq("1.0.0")
    expect(Gem.loaded_specs["servus"].full_gem_path).to end_with("/gem")
  end

  it "registers the shared schema fragments from the initializer" do
    expect(Servus::Schema.keys).to include("core", "houses")
  end

  it "loads Servus's RSpec matchers" do
    expect(self).to respond_to(:servus_arguments_example)
    expect(RSpec::Matchers.method_defined?(:be_service_success)).to be(true)
  end

  it "has ActiveJob available, which event invocation requires" do
    expect(Servus::Base).to respond_to(:call_async)
  end
end
