# frozen_string_literal: true

module Servus
  module Extensions
    # Asynchronous execution extensions for Servus services.
    #
    # This module provides the infrastructure for running services in background jobs
    # via ActiveJob. When loaded, it extends {Servus::Base} with the {Call#call_async} method.
    #
    # @see Servus::Extensions::Async::Call
    # @see Servus::Extensions::Async::Job
    module Async
      require 'active_support/core_ext/module/introspection' # Module#module_parent
      require 'active_support/core_ext/string/inflections' # String#demodulize
      require 'active_support/core_ext/class/subclasses' # Class#descendants

      require 'servus/extensions/async/errors'
      require 'servus/extensions/async/job'
      require 'servus/extensions/async/call'

      # Extension module for async functionality.
      #
      # @api private
      module Ext; end

      # Installs async support on {Servus::Base} and backfills job classes for
      # services that were already defined.
      #
      # The backfill exists because {Call#inherited} — which publishes a service's
      # job constant — only exists once this module is installed, and installation
      # is deferred to +on_load(:active_job)+. Servus's own railtie force-loads
      # +app/events/*_event.rb+, and every service named by an +enqueue+ there loads
      # with it, typically before anything has touched +ActiveJob::Base+. Those
      # services would otherwise never publish a job constant, and a worker — which
      # resolves jobs by name and never calls {Call#call_async} — would fail
      # deserialization with +ActiveJob::UnknownJobClassError+.
      #
      # Only services still reachable under their own name are backfilled. An
      # anonymous service has no constant to publish, and a class whose name no
      # longer resolves to it — replaced by a reload, or defined under a namespace
      # that has since gone — has nothing to publish it under either.
      #
      # @return [void]
      # @api private
      def self.install!
        Servus::Base.extend(Call)

        Servus::Base.descendants.each do |service|
          service.servus_job_class if service.name&.safe_constantize.equal?(service)
        end
      end
    end
  end
end
