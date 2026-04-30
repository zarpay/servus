# frozen_string_literal: true

module Servus
  module Extensions
    module Async
      # ActiveJob for executing Servus services asynchronously.
      #
      # This job is used by {Call#call_async} to execute services in the background.
      # It receives the service class name and arguments, instantiates the service,
      # and executes it via {Servus::Base.call}.
      #
      # @example Enqueued by call_async
      #   Services::SendEmail::Service.call_async(user_id: 123)
      #   # Internally enqueues:
      #   #   Job.perform_later(name: "Services::SendEmail::Service", args: { user_id: 123 })
      #
      # @api private
      class Job < ActiveJob::Base
        queue_as :default

        # Executes the service with the provided arguments.
        #
        # Dynamically loads the service class by name and calls it with the
        # provided keyword arguments.
        #
        # @param name [String] fully-qualified service class name
        # @param args [Hash] keyword arguments to pass to the service
        # @return [Servus::Support::Response] the service execution result
        # @raise [Servus::Extensions::Async::Errors::ServiceNotFoundError] if service class doesn't exist
        #
        # @api private
        def perform(name:, args:)
          constantize!(name).call(**args)
        end

        private

        attr_reader :klass

        # Safely constantizes a class name string.
        #
        # Converts a string class name to its corresponding class constant,
        # raising an error if the class doesn't exist.
        #
        # @param class_name [String] the service class name
        # @return [Class] the service class
        # @raise [Servus::Extensions::Async::Errors::ServiceNotFoundError] if class not found
        #
        # @api private
        def constantize!(class_name)
          "::#{class_name}".safe_constantize ||
            (raise Errors::ServiceNotFoundError, "Service class '#{class_name}' not found.")
        end
      end
    end
  end
end
