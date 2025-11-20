# frozen_string_literal: true

module Servus
  module Support
    # Module that rescues the call method from errors
    module Rescuer
      # Includes the rescuer module into the base class
      #
      # @param base [Class] The base class to include the rescuer module into
      def self.included(base)
        base.class_attribute :rescuable_configs, default: []
        base.singleton_class.prepend(CallOverride)
        base.extend(ClassMethods)
      end

      # Context class that provides success/failure methods to rescue_from blocks
      class BlockContext
        def initialize
          @result = nil
        end

        # Create a success response
        #
        # @param data [Object] The success data
        # @return [Servus::Support::Response] Success response
        def success(data = nil)
          @result = Response.new(true, data, nil)
        end

        # Create a failure response
        #
        # @param message [String] The error message
        # @param type [Class] The error type (defaults to ServiceError)
        # @return [Servus::Support::Response] Failure response
        def failure(message = nil, type: Servus::Support::Errors::ServiceError)
          error = type.new(message)
          @result = Response.new(false, nil, error)
        end

        # Get the result set by success or failure
        attr_reader :result
      end

      # Class methods for rescue_from
      module ClassMethods
        # Rescues the call method from errors
        #
        # By configuring error classes in the rescue_from method, the call method will rescue from those errors
        # and return a failure response with a ServiceError and formatted error message. This prevents the need to
        # to have excessive rescue blocks in the call method.
        #
        # @example Basic usage:
        #   class TestService < Servus::Base
        #     rescue_from SomeError, use: Servus::Support::Errors::ServiceError
        #   end
        #
        # @example With custom error handling block:
        #   class TestService < Servus::Base
        #     rescue_from ActiveRecord::RecordInvalid do |e|
        #       failure("Failed to save record: #{e.message}")
        #     end
        #   end
        #
        # @param [Error] errors One or more errors to rescue from (variadic)
        # @param [Error] use The error to be used (optional, defaults to Servus::Support::Errors::ServiceError)
        # @param [Proc] block Optional block for custom error handling
        def rescue_from(*errors, use: Servus::Support::Errors::ServiceError, &block)
          config = {
            errors: errors,
            error_type: use,
            handler: block
          }

          # Add to rescuable_configs array
          self.rescuable_configs = rescuable_configs + [config]
        end
      end

      # Module that overrides the call method to rescue from errors
      module CallOverride
        # Overrides the call method to rescue from errors
        #
        # @param args [Hash] The arguments passed to the call method
        # @return [Servus::Support::Response] The result of the call method
        def call(**args)
          return super if rescuable_configs.empty?

          begin
            super
          rescue StandardError => e
            handle_rescued_error(e) || raise
          end
        end

        private

        # Handle a rescued error by finding matching config and processing it
        #
        # @param error [StandardError] The error to handle
        # @return [Servus::Support::Response, nil] Response if error was handled, nil otherwise
        def handle_rescued_error(error)
          # Find the first matching config
          config = rescuable_configs.find do |cfg|
            cfg[:errors].any? { |error_class| error.is_a?(error_class) }
          end

          return nil unless config

          if config[:handler]
            # Use the block handler with BlockContext
            context = BlockContext.new
            context.instance_exec(error, &config[:handler])
            context.result
          else
            # Use the default handling
            handle_failure(error, config[:error_type])
          end
        end

        # Returns a failure response with a ServiceError and formatted error message
        #
        # The `failure` method is an instance method of the base class, so it can't be called from this module which
        # is rescuing the call method.
        #
        # @param [Error] error The error to be used
        # @param [Class] type The error type
        # @return [Servus::Support::Response] The failure response
        def handle_failure(error, type)
          error = type.new(template_error_message(error))
          Response.new(false, nil, error)
        end

        # Templates the error message
        #
        # @param [Error] error The error to be used
        # @return [String] The formatted error message
        def template_error_message(error)
          "[#{error.class}]: #{error.message}"
        end
      end
    end
  end
end