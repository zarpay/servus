# frozen_string_literal: true

module Servus
  module Support
    # Enforces that services are invoked through {Servus::Base.call} rather
    # than by instantiating a service and calling its instance `#call`
    # directly. The class-level `.call` runs argument validation, logging,
    # benchmarking, guard handling, result validation, and event emission;
    # calling the instance method directly would silently skip all of that.
    #
    # When included in {Servus::Base}, this module:
    # - Privatizes `.new` on the base class (and, by inheritance, on every
    #   descendant) so `MyService.new` from outside the class raises
    #   `NoMethodError`.
    # - Installs a `method_added` hook on every descendant that privatizes
    #   any instance-level `#call` at definition time.
    #
    # Controlled by {Servus::Config#lockdown_enabled} (default `true`). Set
    # it to `false` to allow direct instantiation and public instance
    # `#call` — useful if you have existing code that relies on those entry
    # points, or if you prefer to opt out of this enforcement entirely.
    #
    # @example Opting out
    #   Servus.configure do |config|
    #     config.lockdown_enabled = false
    #   end
    #
    # @see Servus::Config#lockdown_enabled
    module Lockdown
      # Wires the lockdown hooks into the including class.
      #
      # Extends the base with {ClassMethods} (for {ClassMethods#apply_lockdown!}),
      # prepends {Inherited} so subclasses receive the `method_added` hook,
      # and applies the current config value to `.new`'s visibility.
      #
      # @param base [Class] the class including this module (expected to be {Servus::Base})
      # @return [void]
      # @api private
      def self.included(base)
        base.extend(ClassMethods)
        base.singleton_class.prepend(Inherited)
        base.apply_lockdown!
      end

      # Prepended onto the base class's singleton so that every subclass of
      # {Servus::Base} is automatically extended with {PrivateCall} at
      # class-definition time.
      #
      # @api private
      module Inherited
        # Ensures each subclass has the `method_added` hook installed.
        #
        # @param subclass [Class] the newly defined subclass
        # @return [void]
        def inherited(subclass)
          super
          subclass.extend(PrivateCall)
        end
      end

      # Extended onto every {Servus::Base} subclass. Privatizes any
      # instance-level `#call` as soon as it is defined, provided lockdown
      # is enabled in config at definition time.
      #
      # @api private
      module PrivateCall
        # @param name [Symbol] the name of the newly added method
        # @return [void]
        def method_added(name)
          super
          return unless Servus.config.lockdown_enabled

          private :call if name == :call && public_method_defined?(:call)
        end
      end

      # Class-level helpers installed on {Servus::Base}.
      module ClassMethods
        # Applies {Servus::Config#lockdown_enabled} to `.new`'s visibility.
        # Called on include and re-called whenever the config flag changes.
        #
        # @return [void]
        # @api private
        def apply_lockdown!
          if Servus.config.lockdown_enabled
            singleton_class.send(:private, :new)
          else
            singleton_class.send(:public, :new)
          end
        end
      end
    end
  end
end
