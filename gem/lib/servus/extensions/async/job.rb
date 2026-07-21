# frozen_string_literal: true

module Servus
  module Extensions
    module Async
      # Abstract ActiveJob base class for executing Servus services asynchronously.
      #
      # This class is never enqueued directly. Instead, {Call} generates a named
      # subclass per service (e.g. +Treasury::TransferGold::ServiceJob+) so that
      # background runners like Sidekiq and GoodJob display a meaningful, per-service
      # job name rather than one generic class for every invocation.
      #
      # Each generated subclass carries a reference to its owning service in
      # {servus_service}, set at generation time. {#perform} uses that reference to
      # route back through the standard {Servus::Base.call} lifecycle — validation,
      # logging, benchmarking, guards, and event emission all run exactly as if the
      # service had been called synchronously.
      #
      # @example The class Servus generates for a service
      #   Treasury::TransferGold::ServiceJob < Servus::Extensions::Async::Job
      #   Treasury::TransferGold::ServiceJob.servus_service
      #   # => Treasury::TransferGold::Service
      #
      # @see Servus::Extensions::Async::Call#call_async
      # @api private
      class Job < ActiveJob::Base
        # The service class this job invokes. Set on each generated subclass when
        # {Call.build_servus_job_class} creates it.
        #
        # @return [Class<Servus::Base>, nil] the owning service class
        class_attribute :servus_service

        queue_as :default

        # Executes the job's service with the provided arguments.
        #
        # The service is identified by {servus_service} rather than a serialized
        # name — the job class itself encodes which service to run.
        #
        # @param args [Hash] keyword arguments to pass to the service
        # @return [Servus::Support::Response] the service execution result
        #
        # @api private
        def perform(**args)
          self.class.servus_service.call(**args)
        end
      end
    end
  end
end
