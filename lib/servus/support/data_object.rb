# frozen_string_literal: true

require 'delegate'

module Servus
  module Support
    # A read-only wrapper around Hash data that provides accessor-style access.
    #
    # When service results contain Hash data, +DataObject+ wraps it so keys can be
    # accessed as methods in addition to the standard bracket syntax. Nested Hashes
    # are recursively wrapped, enabling chained access like +data.user.address.city+.
    #
    # Non-Hash values (nil, String, Integer, Array, model instances) pass through
    # unwrapped. This means +data.user+ returns the original object when +user+ is
    # an ActiveRecord model, allowing natural method chaining (+data.user.email+).
    #
    # +DataObject+ inherits from +SimpleDelegator+, so all standard Hash methods
    # (+[]+, +keys+, +each+, +as_json+, +==+, etc.) are delegated transparently.
    #
    # @example Accessor-style access
    #   data = DataObject.wrap({ user: { email: "alice@example.com" } })
    #   data.user.email   # => "alice@example.com"
    #   data[:user]        # => { email: "alice@example.com" } (plain Hash)
    #
    # @example Mixed values
    #   data = DataObject.wrap({ user: user_model, metadata: { source: "api" } })
    #   data.user.email       # => delegates to model's #email method
    #   data.metadata.source  # => "api" (wrapped Hash accessor)
    #
    # @see Servus::Support::Response
    class DataObject < SimpleDelegator
      # Wraps a value in a DataObject if it is a Hash.
      #
      # Non-Hash values are returned unchanged. This is the preferred way to
      # create DataObject instances, as it handles nil and non-Hash types safely.
      #
      # @param data [Object] the value to potentially wrap
      # @return [DataObject] if data is a Hash
      # @return [Array] with Hash elements wrapped if data is an Array
      # @return [Object] the original value otherwise
      def self.wrap(data)
        case data
        when Hash  then new(data)
        when Array then data.map { |item| wrap(item) }
        else data
        end
      end

      private

      # Provides accessor-style access to Hash keys.
      #
      # Only zero-argument, no-block calls trigger key lookup. Methods with
      # arguments (e.g., +fetch+, +dig+) delegate to Hash normally.
      # When the value is a Hash, it is recursively wrapped in a DataObject.
      #
      # @param method_name [Symbol] the method name to look up as a key
      # @return [Object] the value for the key, wrapped if it is a Hash
      # @raise [NoMethodError] if the key does not exist
      def method_missing(method_name, *args, &block)
        return super if args.any? || block

        hash = __getobj__
        if hash.key?(method_name.to_sym)
          self.class.wrap(hash[method_name.to_sym])
        elsif hash.key?(method_name.to_s)
          self.class.wrap(hash[method_name.to_s])
        else
          super
        end
      end

      # @api private
      def respond_to_missing?(method_name, include_private = false)
        hash = __getobj__
        hash.key?(method_name.to_sym) || hash.key?(method_name.to_s) || super
      end
    end
  end
end
