# frozen_string_literal: true

module Servus
  module Support
    # Module that rescues the call method from errors
    module Rescuer
      # Includes the rescuer module into the base class
      #
      # @param base [Class] The base class to include the rescuer module into
      def self.included(base)
        base.class_attribute :rescuable_errors, default: []
        base.class_attribute :rescuable_error_type, default: nil
        base.singleton_class.prepend(CallOverride)
        base.extend(ClassMethods)
      end

      # Class methods for rescue_from
      module ClassMethods
        # Rescues the call method from errors
        #
        # By configuring error classes in the rescue_from method, the call method will rescue from those errors
        # and return a failure response with a ServiceError and formatted error message. This prevents the need to
        # to have excessive rescue blocks in the call method.
        #
        # @example:
        #   class TestService < Servus::Base
        #     rescue_from SomeError, type: Servus::Support::Errors::ServiceError
        #   end
        #
        # @param [Error] errors One or more errors to rescue from (variadic)
        # @param [Error] use The error to be used (optional, defaults to Servus::Support::Errors::ServiceError)
        def rescue_from(*errors, use: Servus::Support::Errors::ServiceError)
          self.rescuable_errors = errors
          self.rescuable_error_type = use
        end
      end

      # Module that overrides the call method to rescue from errors
      module CallOverride
        # Overrides the call method to rescue from errors
        #
        # @param args [Hash] The arguments passed to the call method
        # @return [Servus::Support::Response] The result of the call method
        def call(**args)
          if rescuable_errors.any?
            begin
              super
            rescue *rescuable_errors => e
              handle_failure(e, rescuable_error_type)
            end
          else
            super
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
