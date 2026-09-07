# frozen_string_literal: true

require 'active_job'
require 'active_job/base'

# Rails wires this up through the railtie's `on_load(:active_job)` hook, which
# only fires during a Rails::Application boot. The suite never boots one, so
# without this the whole suite runs with `call_async` undefined — which since
# 1.0.0 means no event invocation works at all.
require 'servus/extensions/async/ext'
Servus::Extensions::Async.install!
