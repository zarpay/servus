# frozen_string_literal: true

module Servus
  module Extensions
    module Async
      # Provides asynchronous service execution via ActiveJob.
      #
      # This module extends {Servus::Base} with the {#call_async} method and, for
      # every service, generates a **named** ActiveJob subclass so background runners
      # (Sidekiq, GoodJob, delayed_job, …) display a meaningful per-service job name
      # instead of one generic class for every invocation.
      #
      # For +Treasury::TransferGold::Service+ the generated job is
      # +Treasury::TransferGold::ServiceJob+ — a sibling constant in the service's
      # parent namespace, subclassing {Servus::Extensions::Async::Job}.
      #
      # @see Call#call_async
      # @see Servus::Extensions::Async::Job
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
        # The service's own named job class ({#servus_job_class}) is enqueued — the
        # class itself identifies the service, so only the service arguments are
        # serialized as the job payload.
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
        # @see #servus_job_class
        def call_async(**args)
          # Extract ActiveJob configuration options
          job_options = args.slice(:wait, :wait_until, :queue, :priority)
          job_options.merge!(args.delete(:job_options) || {}) # merge custom job options
          job_options.compact!

          # Remove special keys that shouldn't be passed to the service
          args.except!(:wait, :wait_until, :queue, :priority, :job_options)

          # The named job class identifies the service — only args are serialized.
          job = job_options.any? ? servus_job_class.set(**job_options) : servus_job_class
          job.perform_later(**args)
        rescue Servus::Support::Errors::ServiceError, Servus::Events::Errors::Error
          # With the :inline and :test adapters perform_later runs the service,
          # so Servus's own errors surface here. Wrapping them as an enqueue
          # failure would blame the wrong layer.
          raise
        rescue StandardError => e
          raise Errors::JobEnqueueError, "Failed to enqueue async job for #{self}: #{e.message}"
        end

        # Configures the service's named job class ({#servus_job_class}), exposing the
        # underlying ActiveJob mechanics on a per-service basis.
        #
        # Provides keyword shortcuts for the two most common options (+queue+ and
        # +priority+) and an optional block, evaluated in the job class's context, for
        # the full ActiveJob surface (+retry_on+, +discard_on+, callbacks, etc.).
        #
        # Settings declared here are class-level defaults for the job. Options passed
        # inline to {#call_async} (e.g. +queue:+, +wait:+) are layered on top of them
        # per enqueue via +ActiveJob::Base.set+, so inline options win.
        #
        # @param queue [Symbol, String, nil] the queue to route the job to (+queue_as+)
        # @param priority [Integer, nil] the job priority (adapter-dependent)
        # @yield evaluated in the job class context for full ActiveJob configuration
        # @return [Class<Servus::Extensions::Async::Job>] the configured job class
        #
        # @example Queue and priority
        #   class Payments::Charge::Service < Servus::Base
        #     async queue: :critical, priority: 10
        #   end
        #
        # @example Full ActiveJob configuration via a block
        #   class Payments::Charge::Service < Servus::Base
        #     async do
        #       retry_on Net::OpenTimeout, wait: 5.seconds, attempts: 3
        #       discard_on ActiveJob::DeserializationError
        #     end
        #   end
        #
        # @see #call_async
        # @see #servus_job_class
        def async(queue: nil, priority: nil, &block)
          job = servus_job_class
          job.queue_as(queue)     if queue
          job.priority = priority if priority
          job.class_eval(&block)  if block
          job
        end

        # Returns the named ActiveJob class for this service, generating and memoizing
        # it on first access.
        #
        # For named services the class is normally created eagerly by the {#inherited}
        # hook when the service is defined; this accessor covers anonymous services
        # (e.g. +Class.new(Servus::Base)+ in tests) whose name only becomes available
        # later, and guarantees a class exists whenever one is needed.
        #
        # @return [Class<Servus::Extensions::Async::Job>] the service's job class
        # @see #call_async
        def servus_job_class
          @servus_job_class ||= build_servus_job_class
        end

        # Eagerly generates the named job class when a service subclass is defined.
        #
        # Anonymous subclasses (+Class.new+) have no name yet, so their job is
        # generated lazily by {#servus_job_class} instead.
        #
        # @param subclass [Class<Servus::Base>] the newly defined service
        # @return [void]
        # @api private
        def inherited(subclass)
          super
          subclass.servus_job_class if subclass.name
        end

        private

        # Generates a named job subclass for this service and installs it as a sibling
        # constant in the service's parent namespace.
        #
        # The constant is +"#{ServiceConst}Job"+, so +Treasury::TransferGold::Service+
        # yields +Treasury::TransferGold::ServiceJob+. Defining it eagerly (see
        # {#inherited}) means Rails' production eager-load defines every service's job
        # at boot, so worker processes can constantize the serialized job name.
        #
        # @return [Class<Servus::Extensions::Async::Job>] the generated job class
        # @api private
        def build_servus_job_class
          raise Servus::Events::Errors::AnonymousServiceError.for(self) if name.nil?

          klass = Class.new(Servus::Extensions::Async::Job)
          klass.servus_service = self

          module_parent.const_set("#{name.demodulize}Job", klass)

          klass
        end
      end
    end
  end
end
