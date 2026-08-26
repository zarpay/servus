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
    class Error < StandardError
      # The +$ref+ string that failed to resolve, when the error came from a ref.
      #
      # @return [String, nil]
      attr_reader :ref

      # The chain of refs that led to the failure, outermost first.
      #
      # @return [Array<String>]
      attr_reader :resolution_path

      # A human label for what was being compiled, e.g.
      # "Treasury::TransferGold::Service arguments schema".
      #
      # @return [String, nil]
      attr_reader :context

      # The description on its own, without the diagnostic clauses appended by
      # {#message}. Retained so an error raised deep in a resolution can be
      # re-raised with context once the frame that knows it is reached.
      #
      # @return [String]
      attr_reader :headline

      # @param headline [String] the description of what went wrong
      # @param ref [String, nil] the offending ref
      # @param resolution_path [Array<String>] refs traversed to reach the failure
      # @param context [String, nil] label for the schema being compiled
      def initialize(headline, ref: nil, resolution_path: [], context: nil)
        @headline = headline
        @ref = ref
        @resolution_path = resolution_path
        @context = context

        super(build_message(headline))
      end

      # Returns a copy of this error carrying resolution diagnostics.
      #
      # Errors are raised where the problem is detected, which is often deeper
      # than the frame that knows which ref chain and which service led there.
      #
      # @param ref [String, nil]
      # @param resolution_path [Array<String>]
      # @param context [String, nil]
      # @return [Error] a new error of the same class
      # @api private
      def with_context(ref: nil, resolution_path: [], context: nil)
        self.class.new(
          headline,
          ref: self.ref || ref,
          resolution_path: resolution_path,
          context: context
        )
      end

      private

      # Assembles the multi-line message from the headline plus whatever
      # diagnostic context is available.
      #
      # @param headline [String]
      # @return [String]
      # @api private
      def build_message(headline)
        parts = [headline]
        parts << "while compiling #{context}" if context
        parts << "(resolution path: #{resolution_path.join(' -> ')})" if resolution_path.length > 1
        parts.join("\n  ")
      end
    end

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
