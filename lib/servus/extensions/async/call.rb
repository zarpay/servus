# frozen_string_literal: true

module Servus
  module Extensions
    module Async
      # Calls the service asynchronously using AsyncCallerJob.
      #
      # Supports all standard ActiveJob scheduling and routing options:
      #   - wait:        <ActiveSupport::Duration>   (e.g., 5.minutes)
      #   - wait_until:  <Time>                      (e.g., 2.hours.from_now)
      #   - queue:       <Symbol/String>             (e.g., :critical, 'low_priority')
      #   - priority:    <Integer>                   (depends on adapter support)
      #   - retry:       <Boolean>                   (custom control for job retry)
      #   - job_options: <Hash>                      (extra options, merged in)
      #
      # Example:
      #   call_async(
      #     wait: 10.minutes,
      #     queue: :low_priority,
      #     priority: 20,
      #     job_options: { tags: ['user_graduation'] },
      #     user_id: current_user.id
      #   )
      #
      module Call
        # @param args [Hash] The arguments to pass to the service and job options.
        # @return [void]
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
