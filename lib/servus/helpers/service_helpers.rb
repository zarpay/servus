# frozen_string_literal: true

module Servus
  module Helpers
    # In-service composition helpers.
    #
    # Auto-mixed into {Servus::Base} so every service has {#call!} available
    # as an instance method for invoking sub-services from within `#call`.
    #
    # @example Composing services from inside a service
    #   class SendDigitalCash::Service < Servus::Base
    #     def call
    #       account = call!(Accounts::Lookup::Service, id: account_id)
    #       ledger  = call!(Ledger::RecordTransfer::Service, account: account, amount: amount)
    #       success(ref: ledger.ref)
    #     end
    #   end
    #
    # For invoking a service from *outside* a service context (controllers,
    # rake tasks, jobs, consoles), see
    # {Servus::Helpers::ControllerHelpers#run_service!}.
    #
    # @see Servus::Base
    # @see Servus::Helpers::ControllerHelpers#run_service!
    module ServiceHelpers
      # Invokes a sub-service from within a service's `#call` and returns its
      # data on success. On failure, halts the *outer* service with the
      # sub-service's failure Response — the outer service's caller receives
      # that Response unchanged (same error object, message, code, http_status).
      #
      # Sugar over:
      #
      #   result = SubService.call(**params)
      #   return result unless result.success?
      #   data = result.data
      #
      # Only call from within a service's `#call` (or helpers reachable from
      # it); the throw is caught by {Servus::Base.call}.
      #
      # @example
      #   def call
      #     data = call!(SendDigitalCash::Service, **params)
      #     success(ref: data.ref)
      #   end
      #
      # @param service_class [Class<Servus::Base>] the sub-service to invoke
      # @param params [Hash] keyword arguments to pass to the sub-service
      # @return [Servus::Support::DataObject, Object] the sub-service's data on success
      # @throw [:guard_failure, Servus::Support::Response] the failure Response, otherwise
      def call!(service_class, **params)
        result = service_class.call(**params)
        return result.data if result.success?

        throw(:guard_failure, result)
      end
    end
  end
end

Servus::Base.include(Servus::Helpers::ServiceHelpers)
