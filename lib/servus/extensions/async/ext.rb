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
      require 'servus/extensions/async/errors'
      require 'servus/extensions/async/job'
      require 'servus/extensions/async/call'

      # Extension module for async functionality.
      #
      # @api private
      module Ext; end
    end
  end
end
