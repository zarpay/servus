# frozen_string_literal: true

module Servus
  module Events
    # Errors raised while resolving or enqueueing event invocations.
    #
    # These deliberately do *not* inherit from {Servus::Support::Errors::ServiceError}.
    # Everything in that hierarchy carries an +#http_status+ and an +#api_error+
    # because it describes a business outcome a caller might render. A missing job
    # backend, or a service that cannot be enqueued, is a configuration problem —
    # there is no sensible HTTP status for it.
    #
    # @see Servus::Events::Invocation
    module Errors
      # Base class for every event invocation error.
      class Error < StandardError; end

      # Raised when an event invocation cannot be enqueued because ActiveJob is
      # not loaded.
      #
      # Event invocation is always asynchronous, so an event that reacts to
      # anything needs a job backend. Servus's core — services, schemas, guards,
      # and the bus itself — works without one; only +enqueue+ declarations
      # require it.
      class AsyncBackendMissingError < Error
        # @param service [Class] the service that could not be enqueued
        # @return [AsyncBackendMissingError]
        def self.for(service)
          new(
            "Cannot enqueue #{service} from an event: ActiveJob is not loaded. " \
            'Event invocation is always asynchronous and runs through ActiveJob. ' \
            'Require active_job, or remove the enqueue declaration.'
          )
        end
      end

      # Raised when a service has no name, so no job class can be generated for it.
      #
      # ActiveJob resolves a job on the worker by its serialized class name, so a
      # service created with +Class.new(Servus::Base)+ has nothing to serialize.
      # This surfaces almost exclusively in tests — assign the class to a constant,
      # or use +stub_const+.
      class AnonymousServiceError < Error
        # @param service [Class] the anonymous service
        # @return [AnonymousServiceError]
        def self.for(service)
          new(
            "Cannot generate a job class for #{service.inspect}: it is anonymous. " \
            'ActiveJob resolves jobs by class name, so a service must be assigned ' \
            'to a constant before it can be enqueued.'
          )
        end
      end
    end
  end
end
