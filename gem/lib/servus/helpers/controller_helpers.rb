# frozen_string_literal: true

module Servus
  module Helpers
    # Rails controller helper methods for service integration.
    #
    # Provides convenient methods for calling services from controllers and
    # handling their responses. Automatically included in ActionController::Base
    # when Servus is loaded in a Rails application.
    #
    # @example Including in a controller
    #   class ApplicationController < ActionController::Base
    #     include Servus::Helpers::ControllerHelpers
    #   end
    #
    # @see #run_service
    # @see #render_service_error
    module ControllerHelpers
      # Executes a service and handles success/failure automatically.
      #
      # On success, stores the result in @result for use in views.
      # On failure, renders the error as JSON with the appropriate HTTP status.
      #
      # @param klass [Class] service class to execute (must inherit from {Servus::Base})
      # @param params [Hash] keyword arguments to pass to the service
      # @return [Servus::Support::Response, nil] the service result, or nil if error rendered
      #
      # @example Basic usage
      #   class UsersController < ApplicationController
      #     def create
      #       run_service Services::CreateUser::Service, user_params
      #     end
      #   end
      #
      # @see #render_service_error
      # @see Servus::Base.call
      def run_service(klass, params)
        @result = klass.call(**params)
        render_service_error(@result.error) unless @result.success?
      end

      # Renders a service error as a JSON response.
      #
      # Uses error.http_status for the response status code and
      # error.api_error for the response body.
      #
      # Override this method in your controller to customize error response format.
      #
      # @param error [Servus::Support::Errors::ServiceError] the error to render
      # @return [void]
      #
      # @example Default behavior
      #   # Renders: { error: { code: :not_found, message: "User not found" } }
      #   # With status: 404
      #
      # @example Custom error rendering
      #   def render_service_error(error)
      #     render json: {
      #       error: {
      #         type: error.api_error[:code],
      #         details: error.message,
      #         timestamp: Time.current
      #       }
      #     }, status: error.http_status
      #   end
      #
      # @see Servus::Support::Errors::ServiceError#api_error
      # @see Servus::Support::Errors::ServiceError#http_status
      def render_service_error(error)
        render json: { error: error.api_error }, status: error.http_status
      end
    end
  end
end
