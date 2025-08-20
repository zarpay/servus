# frozen_string_literal: true

module Servus
  module Helpers
    # Controller helpers
    module ControllerHelpers
      # Run a service object and return the result
      #
      # This method is a helper method for controllers to run a service object and return the result.
      # Servus errors (Servus::Support::Errors::*) all impliment an api_error method that returns a hash with
      # a code and message. The service_object_error method and any custom implimentation, can be used to
      # automatically format and return an API error response.
      #
      # @example:
      #   class TestController < ApplicationController
      #     def index
      #       run_service MyService::Service, params
      #     end
      #   end
      #
      # The result of the service is stored in the instance variable @result, which can be used
      # in views to template a response.
      #
      # @example:
      #   json.data do
      #     json.some_key @result.data[:some_key]
      #   end
      #
      # When investigating the servus error classes, you can see the api_error method implimentation
      # for each error type. Below is an example implementation of the service_object_error method, which
      # could be overwritten to meet a specific applications needs.
      #
      # @example:
      #   # Example implementation of api_error on Servus::Support::Errors::ServiceError
      #   # def api_error
      #   #   { code: :bad_request, message: message }
      #   # end
      #
      #   Example implementation of service_object_error
      #   def service_object_error(api_error)
      #     render json: api_error, status: api_error[:code]
      #   end
      #
      # @param klass [Class] The service class
      # @param params [Hash] The parameters to pass to the service
      # @return [Servus::Support::Response] The result of the service
      #
      # @see Servus::Support::Errors::ServiceError
      def run_service(klass, params)
        @result = klass.call(**params)
        render_service_object_error(@result.error.api_error) unless @result.success?
      end

      # Service object error renderer
      #
      # This method is a helper method for controllers to render service object errors.
      #
      # @param api_error [Hash] The API error response
      #
      # @see Servus::Support::Errors::ServiceError
      def render_service_object_error(api_error)
        render json: api_error, status: api_error[:code]
      end
    end
  end
end
