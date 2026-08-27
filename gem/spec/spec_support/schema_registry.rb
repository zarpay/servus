# frozen_string_literal: true

# Shared context for specs that register schema fragments.
#
# The registry is process-global, so any example that registers a fragment must
# restore the previous state or it leaks into later examples. Tag an example or
# group with `:schema_registry` to get a snapshot/restore around it.
#
# @example
#   RSpec.describe MyThing, :schema_registry do
#     before { Servus::Schema.register('core', { '$defs' => { 'id' => { 'type' => 'integer' } } }) }
#   end
RSpec.shared_context 'with a clean schema registry' do
  around do |example|
    snapshot = Servus::Schema.snapshot
    Servus::Schema.reset!
    example.run
  ensure
    Servus::Schema.restore(snapshot)
  end
end

RSpec.configure do |config|
  config.include_context 'with a clean schema registry', :schema_registry
end
