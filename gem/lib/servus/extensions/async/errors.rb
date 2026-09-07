# frozen_string_literal: true

module Servus
  module Extensions
    module Async
      # Error classes for asynchronous service execution.
      #
      # These errors are raised when async operations fail, such as job enqueueing
      # failures or missing service classes during job execution.
      module Errors
        # Base error class for all async extension errors.
        #
        # All async-related errors inherit from this class for easy rescue handling.
        class AsyncError < StandardError; end

        # Raised when enqueueing a background job fails.
        #
        # This typically occurs due to connection issues with the job backend
        # (Redis, database, etc.) or configuration problems.
        #
        # @example
        #   Services::SendEmail::Service.call_async(user_id: 123)
        #   # => Servus::Extensions::Async::Errors::JobEnqueueError: Failed to enqueue async job
        class JobEnqueueError < AsyncError; end

        # Raised when +call_async+ is invoked on a service whose generated job was
        # never published because the application already owns the constant.
        #
        # The generated job class exists but has no name, and ActiveJob serializes a
        # job by its class name — enqueueing it would succeed and then fail on the
        # worker at deserialization, far from the call site. Refusing here keeps the
        # failure where it was caused.
        #
        # @see Servus::Extensions::Async::Call#call_async
        class JobNameConflictError < AsyncError
          # @param service [Class] the service whose job constant is taken
          # @param const_name [String] the constant the application owns
          # @return [JobNameConflictError]
          def self.for(service, const_name)
            new(
              "Cannot enqueue #{service.name}: its generated job was not published because " \
              "#{const_name} is already defined by the application. An unnamed job would " \
              'enqueue but no worker could deserialize it. Rename the service or the ' \
              "application's #{const_name} to stop the collision."
            )
          end
        end
      end
    end
  end
end
