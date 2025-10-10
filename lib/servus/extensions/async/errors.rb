# frozen_string_literal: true

module Servus
  module Extensions
    module Async
      module Errors
        # Base error class for async extensions
        class AsyncError < StandardError; end

        # Error raised when the job fails to enqueue
        class JobEnqueueError < AsyncError; end

        # Error raised when the service class cannot be found
        class ServiceNotFoundError < AsyncError; end
      end
    end
  end
end
