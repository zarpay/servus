# frozen_string_literal: true

require 'digest'
require 'json'

module Servus
  module Events
    # A normalized, executable representation of "call this service with
    # these params."
    #
    # Routers return arrays of Invocation objects. The Bus collects them,
    # deduplicates by +#key+ (first wins), and calls +#execute+ on each.
    #
    # An Invocation separates *identity* (service + params) from
    # *scheduling* (queue, priority, delay). The +#key+ is derived only
    # from the identity — two invocations that call the same service with
    # the same params are considered duplicates regardless of their options.
    #
    # Invocations are always enqueued, never run inline. A reaction that ran
    # synchronously would put its latency and its failures back into the
    # emitting service, which is what events exist to avoid.
    #
    # @example
    #   Invocation.new(
    #     service: Notifications::Send::Service,
    #     params:  { user_id: "abc-123" },
    #     options: { queue: :mailers, priority: 5 }
    #   )
    #
    # @see Servus::Events::Router
    # @see Servus::Events::Bus
    class Invocation
      # @return [Class] the service class to enqueue (must respond to +.call_async+)
      attr_reader :service

      # @return [Hash] keyword arguments passed to the service
      attr_reader :params

      # @return [Hash] scheduling options — +queue+, +wait+, +wait_until+,
      #   +priority+, +job_options+
      attr_reader :options

      # @param service [Class] the service class
      # @param params [Hash] keyword arguments for the service
      # @param options [Hash] scheduling options
      def initialize(service:, params:, options: {})
        @service = service
        @params  = params
        @options = options
      end

      # Enqueues the invocation via ActiveJob.
      #
      # Scheduling options (queue, wait, priority, and so on) are merged into
      # the +call_async+ keyword arguments.
      #
      # @return [void]
      # @raise [Servus::Events::Errors::AsyncBackendMissingError] if ActiveJob is not loaded
      def enqueue
        raise Errors::AsyncBackendMissingError.for(service) unless service.respond_to?(:call_async)

        service.call_async(**params, **async_options)
      end

      # A deterministic deduplication key derived from the service class
      # and params. Two invocations with the same key are considered
      # duplicates — the Bus keeps the first and skips the rest.
      #
      # Options are intentionally excluded: identity is *what* to call,
      # not *how* to call it.
      #
      # @return [String] SHA-256 hex digest
      def key
        Digest::SHA256.hexdigest("#{service}:#{params.to_json}")
      end

      private

      # Extracts scheduling options for +call_async+.
      #
      # @return [Hash]
      # @api private
      def async_options
        options.slice(:queue, :wait, :wait_until, :priority, :job_options).compact
      end
    end
  end
end
