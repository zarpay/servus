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
    # @see #render_service_object_error
    module ControllerHelpers
      # Executes a service and handles success/failure automatically.
      #
      # This method runs the service with the provided parameters. On success,
      # it stores the result in @result for use in views. On failure, it
      # automatically calls {#render_service_object_error} with the error details.
      #
      # The result is always stored in the @result instance variable, making it
      # available in views for rendering successful responses.
      #
      # @param klass [Class] service class to execute (must inherit from {Servus::Base})
      # @param params [Hash] keyword arguments to pass to the service
      # @return [Servus::Support::Response, nil] the service result, or nil if error rendered
      #
      # @example Basic usage
      #   class UsersController < ApplicationController
      #     def create
      #       run_service Services::CreateUser::Service, user_params
      #       # If successful, @result is available for rendering
      #       # If failed, error response is automatically rendered
      #     end
      #   end
      #
      # @example Using @result in views
      #   # In your Jbuilder view (create.json.jbuilder)
      #   json.user do
      #     json.id @result.data[:user_id]
      #     json.email @result.data[:email]
      #   end
      #
      # @example Manual success handling
      #   class UsersController < ApplicationController
      #     def create
      #       run_service Services::CreateUser::Service, user_params
      #       return unless @result.success?
      #
      #       # Custom success handling
      #       redirect_to user_path(@result.data[:user_id])
      #     end
      #   end
      #
      # @see #render_service_object_error
      # @see Servus::Base.call
      def run_service(klass, params)
        @result = klass.call(**params)
        render_service_object_error(@result.error.api_error) unless @result.success?
      end

      # Renders a service error as a JSON response.
      #
      # This method is called automatically by {#run_service} when a service fails,
      # but can also be called manually for custom error handling. It renders the
      # error's api_error hash with the appropriate HTTP status code.
      #
      # Override this method in your controller to customize error response format.
      #
      # @param api_error [Hash] error hash with :code and :message keys from {Servus::Support::Errors::ServiceError#api_error}
      # @return [void]
      #
      # @example Default behavior
      #   # Renders: { code: :not_found, message: "User not found" }
      #   # With status: 404
      #   render_service_object_error(result.error.api_error)
      #
      # @example Custom error rendering
      #   class ApplicationController < ActionController::Base
      #     def render_service_object_error(api_error)
      #       render json: {
      #         error: {
      #           type: api_error[:code],
      #           details: api_error[:message],
      #           timestamp: Time.current
      #         }
      #       }, status: api_error[:code]
      #     end
      #   end
      #
      # @see Servus::Support::Errors::ServiceError#api_error
      # @see #run_service
      def render_service_object_error(api_error)
        render json: api_error, status: api_error[:code]
      end
    end
  end
end
