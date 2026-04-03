# frozen_string_literal: true

module Servus
  module Extensions
    module Lazily
      # Provides lazy record resolution for service inputs.
      #
      # This module extends {Servus::Base} with the {#lazily} class method, enabling
      # services to accept either a record ID or an already-loaded record instance.
      # Resolution happens lazily on first access and is memoized.
      #
      # @see Lazily#lazily
      module Call
        # Declares a lazy record resolver for a service input.
        #
        # Defines an accessor method that lazily resolves the input value to a record.
        # If the value is already an instance of the target class, it is returned directly.
        # If the value is an ID (or other lookup value), it is resolved via the target
        # class's +.find+ or +.find_by!+ method. Arrays are resolved via +.where+.
        #
        # The resolved record is written back to the instance variable, so subsequent
        # calls return the same object without re-querying.
        #
        # @param name [Symbol] the param/ivar name, also becomes the accessor method
        # @param finds [Class] the model class to resolve against (e.g., +User+, +Account+)
        # @param by [Symbol] the lookup column (default: +:id+). When +:id+, uses +.find+.
        #   Otherwise uses +.find_by!(column: value)+.
        # @return [void]
        #
        # @example Basic usage with .find
        #   lazily :user, finds: User
        #   # user: 123       → User.find(123)
        #   # user: user_inst → returns user_inst directly
        #
        # @example Custom column lookup
        #   lazily :account, finds: Account, by: :uuid
        #   # account: "abc-def" → Account.find_by!(uuid: "abc-def")
        #
        # @example Array input
        #   lazily :users, finds: User
        #   # users: [1, 2, 3] → User.where(id: [1, 2, 3])
        #
        # @note Only available when ActiveRecord is loaded (via Railtie)
        # @see Servus::Base.call
        def lazily(name, finds:, by: :id)
          (@lazy_resolvers ||= {})[name] = { klass: finds, by: by }
          define_resolver_method(name, finds, by)
        end

        # Returns the hash of registered lazy resolvers for this service class.
        #
        # @return [Hash{Symbol => Hash}] resolver configurations keyed by name
        # @api private
        def lazy_resolvers
          @lazy_resolvers || {}
        end

        private

        # Defines a lazy accessor method on a prepended module.
        #
        # @param name [Symbol] the method/ivar name
        # @param klass [Class] the target model class
        # @param by [Symbol] the lookup column
        # @api private
        def define_resolver_method(name, klass, by)
          mod = (@_resolver_module ||= Module.new)
          prepend(mod) unless ancestors.include?(mod)

          mod.define_method(name) do
            @_lazily_resolved ||= {}
            return instance_variable_get(:"@#{name}") if @_lazily_resolved[name]

            resolved = Resolver.call(instance_variable_get(:"@#{name}"), klass: klass, by: by, name: name)
            @_lazily_resolved[name] = true
            instance_variable_set(:"@#{name}", resolved)
          end
        end
      end
    end
  end
end
