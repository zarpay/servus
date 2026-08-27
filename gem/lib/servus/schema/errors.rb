# frozen_string_literal: true

module Servus
  module Schema
    # Base class for every schema registry and compilation error.
    #
    # These deliberately do *not* inherit from {Servus::Support::Errors::ServiceError}.
    # Everything in that hierarchy carries an +#http_status+ and an +#api_error+
    # because it describes a business outcome a caller might render. A malformed
    # +$ref+ or an unregistered fragment key is a programming error in the schema
    # itself — there is no sensible HTTP status for it, and rescuing it would
    # reintroduce exactly the silent non-validation this design exists to prevent.
    #
    # @see Servus::Schema
    # @see Servus::Schema::Compiler
    class Error < StandardError; end

    # Raised when a +$ref+ names a fragment key that is not registered.
    #
    # This is the error the whole registry design exists to produce. A lookup
    # that returned nil instead would let a service that appears to declare a
    # contract run with no validation at all, indefinitely and silently.
    class UnknownKeyError < Error
      # Builds the error for a missed lookup, suggesting the nearest key.
      #
      # @param key [String] the key that was not found
      # @param available [Array<String>] currently registered keys
      # @return [UnknownKeyError]
      def self.for(key, available:)
        return new(nothing_registered(key)) if available.empty?

        new("unknown schema key #{key.inspect}.#{suggestion(key, available)}")
      end

      # @param key [String]
      # @return [String]
      # @api private
      def self.nothing_registered(key)
        "unknown schema key #{key.inspect}: no schema fragments are registered. " \
          'Register one with Servus::Schema.register(key, fragment).'
      end

      # @param key [String]
      # @param available [Array<String>]
      # @return [String] a " Did you mean: ..." clause, or an empty string
      # @api private
      def self.suggestion(key, available)
        matches = DidYouMean::SpellChecker.new(dictionary: available).correct(key)
        return '' if matches.empty?

        " Did you mean: #{matches.map(&:inspect).join(', ')}?"
      end

      private_class_method :nothing_registered, :suggestion
    end

    # Raised when a +$ref+ names a registered key but the path within it is absent.
    class RefNotFoundError < Error; end

    # Raised when a +$ref+ value is not a supported ref form.
    class InvalidRefError < Error; end

    # Raised when a key passed to {Servus::Schema.register} cannot be referenced.
    class InvalidKeyError < Error; end

    # Raised when refs form a cycle.
    class CircularReferenceError < Error; end

    # Raised when a schema nests more deeply than {Servus::Schema::Compiler::MAX_DEPTH}.
    #
    # Distinct from {CircularReferenceError} on purpose: a deep but acyclic
    # schema is a different problem from a cycle, and conflating them is what
    # makes depth-counter-only implementations reject valid schemas.
    class DepthExceededError < Error; end
  end
end
