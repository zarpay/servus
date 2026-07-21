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
      end
    end
  end
end
