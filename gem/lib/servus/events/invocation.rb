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
    # *execution strategy* (async, queue, priority, etc.). The +#key+
    # is derived only from the identity — two invocations that call the
    # same service with the same params are considered duplicates
    # regardless of their options.
    #
    # @example Sync invocation
    #   Invocation.new(
    #     service: Rewards::Grant::Service,
    #     params:  { user_id: "abc-123" },
    #     options: {}
    #   )
    #
    # @example Async invocation with scheduling options
    #   Invocation.new(
    #     service: Notifications::Send::Service,
    #     params:  { user_id: "abc-123" },
    #     options: { async: true, queue: :mailers, priority: 5 }
    #   )
    #
    # @see Servus::Events::Router
    # @see Servus::Events::Bus
    class Invocation
      # @return [Class] the service class to call (must respond to +.call+ or +.call_async+)
      attr_reader :service

      # @return [Hash] keyword arguments passed to the service
      attr_reader :params

      # @return [Hash] execution options — +async+, +queue+, +wait+,
      #   +wait_until+, +priority+, +job_options+
      attr_reader :options

      # @param service [Class] the service class
      # @param params [Hash] keyword arguments for the service
      # @param options [Hash] execution options
      def initialize(service:, params:, options: {})
        @service = service
        @params  = params
        @options = options
      end

      # Executes the invocation.
      #
      # Delegates to +service.call+ for synchronous invocations or
      # +service.call_async+ for asynchronous ones. Async scheduling
      # options (queue, wait, priority, etc.) are merged into the
      # call_async kwargs.
      #
      # @return [Servus::Support::Response, void]
      def execute
        if options[:async]
          service.call_async(**params, **async_options)
        else
          service.call(**params)
        end
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
      def async_options
        options.slice(:queue, :wait, :wait_until, :priority, :job_options).compact
      end
    end
  end
end
