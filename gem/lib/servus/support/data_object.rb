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

      # A key that names a Hash method is unreachable through method_missing:
      # SimpleDelegator resolves the method first, so data.size returns the count
      # instead of the stored value (EVENTUS-25, Fizzy 2073). Defining the
      # accessor on the instance makes it win, and only for a colliding key, so a
      # hash without one keeps the real Hash method.

      def shadow_colliding_keys(data)
        data.each_key { |key| shadow_key(data, key.to_sym) }
      end

      # respond_to? sees methods Hash inherits and ones mixed in later
      # (ActiveSupport adds as_json), which is the set SimpleDelegator resolves
      # before method_missing.
      def shadow_key(data, name)
        return unless respond_to?(name)
        return unless data.key?(name) || data.key?(name.to_s)

        define_singleton_method(name) { |*call_args, &call_block| read_or_delegate(name, *call_args, &call_block) }
      end

      def read_or_delegate(name, *call_args, &call_block)
        hash = __getobj__
        return hash.public_send(name, *call_args, &call_block) if call_args.any? || call_block
        return hash.public_send(name) unless hash.key?(name) || hash.key?(name.to_s)

        self.class.wrap(hash.key?(name) ? hash[name] : hash[name.to_s])
      end

      # Provides accessor-style access to Hash keys.
      #
      # Only zero-argument, no-block calls trigger key lookup. Methods with
      # arguments (e.g., +fetch+, +dig+) delegate to Hash normally.
      # When the value is a Hash, it is recursively wrapped in a DataObject.
      #
      # @param method_name [Symbol] the method name to look up as a key
      # @return [Object] the value for the key, wrapped if it is a Hash
      # @raise [NoMethodError] if the key does not exist
      def initialize(data)
        super
        shadow_colliding_keys(data)
      end

      def method_missing(method_name, *args, &block)
        return __getobj__.public_send(method_name, *args, &block) if args.any? || block

        read_or_delegate(method_name)
      end

      # @api private
      def respond_to_missing?(method_name, include_private = false)
        hash = __getobj__
        hash.key?(method_name.to_sym) || hash.key?(method_name.to_s) || super
      end
    end
  end
end
