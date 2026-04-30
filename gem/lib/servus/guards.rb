# frozen_string_literal: true

module Servus
  # Module providing guard functionality to Servus services.
  #
  # Guard methods are defined directly on this module when guard classes
  # inherit from Servus::Guard. The inherited hook triggers method definition,
  # so no registry or method_missing is needed.
  #
  # @example Using guards in a service
  #   class TransferService < Servus::Base
  #     def call
  #       enforce_presence!(user: user, account: account)
  #       enforce_state!(on: account, check: :status, is: :active)
  #       # ... perform transfer ...
  #       success(result)
  #     end
  #   end
  #
  # @see Servus::Guard
  module Guards
    # Guard methods are defined dynamically via Servus::Guard.inherited
    # when guard classes are loaded. Each guard class defines:
    #   - enforce_<name>!  (throws :guard_failure on failure)
    #   - check_<name>?  (returns boolean)

    class << self
      # Loads default guards if configured.
      #
      # Called after Guards module is defined to load built-in guards
      # when Servus.config.include_default_guards is true.
      #
      # @return [void]
      # @api private
      def load_defaults
        return unless Servus.config.include_default_guards

        require_relative 'guards/presence_guard'
        require_relative 'guards/truthy_guard'
        require_relative 'guards/falsey_guard'
        require_relative 'guards/state_guard'
      end
    end
  end
end

# Load default guards based on configuration
Servus::Guards.load_defaults
