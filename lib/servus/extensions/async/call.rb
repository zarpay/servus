# frozen_string_literal: true

module Servus
  module Extensions
    module Async
      # Provides asynchronous service execution via ActiveJob.
      #
      # This module extends {Servus::Base} with the {#call_async} method, enabling
      # services to be executed in background jobs. Requires ActiveJob to be loaded.
      #
      # @see Call#call_async
      module Call
        # Enqueues the service for asynchronous execution via ActiveJob.
        #
        # This method schedules the service to run in a background job, supporting
        # all standard ActiveJob options for scheduling, queue routing, and priority.
        #
        # Service arguments are passed as keyword arguments alongside job configuration.
        # Job-specific options are extracted and the remaining arguments are passed
        # to the service's initialize method.
        #
        # @param args [Hash] combined service arguments and job configuration options
        # @option args [ActiveSupport::Duration] :wait delay before execution (e.g., 5.minutes)
        # @option args [Time] :wait_until specific time to execute (e.g., 2.hours.from_now)
        # @option args [Symbol, String] :queue queue name (e.g., :low_priority)
        # @option args [Integer] :priority job priority (adapter-dependent)
        # @option args [Hash] :job_options additional ActiveJob options
        #
        # @return [void]
        # @raise [Servus::Extensions::Async::Errors::JobEnqueueError] if job enqueueing fails
        #
        # @example Basic async execution
        #   Services::SendEmail::Service.call_async(
        #     user_id: 123,
        #     template: :welcome
        #   )
        #
        # @example With delay
        #   Services::SendReminder::Service.call_async(
        #     wait: 1.day,
        #     user_id: 123
        #   )
        #
        # @example With queue and priority
        #   Services::ProcessPayment::Service.call_async(
        #     queue: :critical,
        #     priority: 10,
        #     order_id: 456
        #   )
        #
        # @example With custom job options
        #   Services::GenerateReport::Service.call_async(
        #     wait_until: Date.tomorrow.beginning_of_day,
        #     job_options: { tags: ['reports', 'daily'] },
        #     report_type: :sales
        #   )
        #
        # @note Only available when ActiveJob is loaded (typically in Rails applications)
        # @see Servus::Base.call
        def call_async(**args)
          # Extract ActiveJob configuration options
          job_options = args.slice(:wait, :wait_until, :queue, :priority)
          job_options.merge!(args.delete(:job_options) || {}) # merge custom job options

          # Remove special keys that shouldn't be passed to the service
          args.except!(:wait, :wait_until, :queue, :priority, :job_options)

          # Build job with optional delay, scheduling, or queue settings
          job = job_options.any? ? Job.set(**job_options.compact) : Job

          # Enqueue the job asynchronously
          job.perform_later(name: name, args: args)
        rescue StandardError => e
          raise Errors::JobEnqueueError, "Failed to enqueue async job for #{self}: #{e.message}"
        end
      end
    end
  end
end
