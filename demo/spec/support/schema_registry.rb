# frozen_string_literal: true

# =============================================================================
# Schema registry isolation
# =============================================================================
#
# `Servus::Schema` is process-global: fragments registered by the initializer
# are visible to every example. That is what you want almost all of the time —
# services reference `#/core/$defs/gold_dragons` and it resolves.
#
# It is exactly what you do NOT want in a spec that registers its own fragment,
# re-registers an existing key with a different value, or calls `reset!`. Those
# would leak into every later example.
#
# Tag such an example `:schema_registry` to get a snapshot/restore around it.
# This mirrors the shared context the gem's own suite uses.
#
#   RSpec.describe "custom fragments", :schema_registry do
#     before { Servus::Schema.register("scratch", { "$defs" => {} }) }
#   end
RSpec.shared_context "with an isolated schema registry" do
  around do |example|
    snapshot = Servus::Schema.snapshot
    example.run
  ensure
    Servus::Schema.restore(snapshot)
  end
end

RSpec.configure do |config|
  config.include_context "with an isolated schema registry", :schema_registry
end
