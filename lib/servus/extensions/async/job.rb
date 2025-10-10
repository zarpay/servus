# frozen_string_literal: true

module Servus
  module Extensions
    module Async
      # Job to run a service class with given arguments.
      #
      # This job will be migrated to Servus once it's stable as a .call_async method.
      # It takes the fully-qualified class name of the service as a string and any keyword arguments
      # required by the service's .call method.
      #
      # Example usage:
      #   RunServiceJob.perform_later('SomeModule::SomeService', arg1: value1, arg2: value2)
      #
      # This will invoke SomeModule::SomeService.call(arg1: value1, arg2: value2) in a background job.
      #
      # Errors during service execution are logged.
      class Job < ActiveJob::Base
        queue_as :default

        def perform(name:, args:)
          constantize!(name).call(**args)
        end

        private

        attr_reader :klass

        def constantize!(class_name)
          class_name.safe_constantize || (raise Errors::ServiceNotFoundError,
                                                "Service class '#{class_name}' not found.")
        end
      end
    end
  end
end
