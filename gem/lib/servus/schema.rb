# frozen_string_literal: true

require 'did_you_mean'

module Servus
  # Registry of reusable JSON Schema fragments, and the entry point for
  # compiling a schema that references them.
  #
  # Servus services and events declare their contracts inline via the +schema+
  # DSL. That keeps a service's inputs and outputs visible in the file that
  # implements it. The cost of inline-only declaration is duplication: the same
  # +amount+ or +timestamp+ shape gets copy-pasted across every service that
  # touches it.
  #
  # Registered fragments close that gap without giving up explicitness. A
  # fragment is registered under a key, and services reference into it with a
  # standard JSON Schema +$ref+. A service that references a shared type is
  # still explicitly declaring that type — it just names it once.
  #
  # @example Registering a fragment
  #   Servus::Schema.register('core', {
  #     '$defs' => {
  #       'amount' => { 'type' => 'integer', 'minimum' => 0 }
  #     }
  #   })
  #
  # @example Referencing it from a service
  #   class Treasury::TransferGold::Service < Servus::Base
  #     schema arguments: {
  #       type: 'object',
  #       required: ['gold_dragons'],
  #       properties: {
  #         gold_dragons: { '$ref' => '#/core/$defs/amount' }
  #       }
  #     }
  #   end
  #
  # Lookups never return nil. An unregistered key raises {UnknownKeyError} at
  # the point of use, because the alternative — silently skipping validation for
  # a service that appears to declare a contract — is the worst failure mode
  # this system has.
  #
  # @see Servus::Schema::Compiler
  # @see Servus::Base.schema
  module Schema
    @registry = {}.freeze
    @cache = Cache.new
    @mutex = Mutex.new

    class << self
      # Memoized ref resolutions and the generation counter derived from them.
      #
      # @return [Servus::Schema::Cache]
      # @api private
      attr_reader :cache

      # Monotonic counter bumped whenever the registry changes.
      #
      # Consumers memoize compiled schemas alongside the generation they were
      # compiled under, and recompile when it moves. That makes registry
      # updates propagate without any explicit dependency tracking.
      #
      # @return [Integer]
      def generation = cache.generation

      # Registers a reusable schema fragment under +key+.
      #
      # Re-registering an equal value is a silent no-op, so calling this from a
      # Rails +to_prepare+ block is safe. Re-registering a *different* value
      # replaces it, logs an override, and bumps {generation} — which
      # invalidates every compiled schema that referenced it.
      #
      # @param key [String, Symbol] the fragment key, referenced as +#/<key>/...+
      # @param fragment [Hash] the schema fragment
      # @return [ActiveSupport::HashWithIndifferentAccess] the normalized fragment
      # @raise [InvalidKeyError] if the key is blank or contains a +/+
      # @raise [ArgumentError] if the fragment is not a Hash
      #
      # @example
      #   Servus::Schema.register('core', { '$defs' => { 'id' => { 'type' => 'integer' } } })
      def register(key, fragment)
        key = normalize_key(key)
        normalized = normalize_fragment(key, fragment)

        cache.invalidate! if store(key, normalized)

        normalized
      end

      # Returns a registered fragment, or a definition within one.
      #
      # Given no path, returns the whole fragment. Given path segments, walks
      # them as literal keys — the same addressing a +$ref+ uses, so
      # +fetch(key, *path)+ reads exactly what +ref(key, *path)+ points at.
      #
      # A missing path raises rather than returning nil. Reaching for the
      # fragment and calling +dig+ would return nil on a typo, which is the
      # silent failure this registry exists to prevent.
      #
      # Fragments are returned as authored, with any +$ref+s intact. Use
      # {compile} to resolve them.
      #
      # @param key [String, Symbol] the fragment key
      # @param path [Array<String, Symbol>] segments to walk within the fragment
      # @return [ActiveSupport::HashWithIndifferentAccess, Object] the frozen fragment or definition
      # @raise [UnknownKeyError] if nothing is registered under +key+
      # @raise [RefNotFoundError] if the path is not present in the fragment
      #
      # @example
      #   Servus::Schema.fetch('core')
      #   Servus::Schema.fetch('core', '$defs', 'amount')
      def fetch(key, *path)
        key = key.to_s
        fragment = @registry.fetch(key) { raise UnknownKeyError.for(key, available: @registry.keys) }

        Path.walk(fragment, key, path.map(&:to_s))
      end

      # Returns a fragment, or a definition within one, with all +$ref+s resolved.
      #
      # The compiled counterpart to {fetch}: same addressing, but the result is
      # self-contained and ready to validate against. This is usually what
      # application code outside a service wants — a controller validating a
      # request body, a serializer checking a response shape.
      #
      # Results are memoized, so asking repeatedly for the same address is cheap.
      #
      # @param key [String, Symbol] the fragment key
      # @param path [Array<String, Symbol>] segments to walk within the fragment
      # @return [Hash, Object] the compiled fragment or definition
      # @raise [UnknownKeyError] if nothing is registered under +key+
      # @raise [RefNotFoundError] if the path is not present in the fragment
      # @raise [Error] if a ref within it cannot be resolved
      #
      # @example
      #   Servus::Schema.resolve('endpoints::trades::create', '$defs', 'request')
      #   # => { "type" => "object", "properties" => { "price" => { "type" => "integer" } } }
      def resolve(key, *path)
        pointer = ref(key, *path)

        compile(pointer, context: "schema #{pointer['$ref']}")
      end

      # Compiles every registered fragment, resolving all +$ref+s.
      #
      # Returns a hash of key to compiled fragment, mirroring the registry's own
      # shape so keys stay addressable and the result serializes straight to
      # JSON. Useful for producing a single schema asset for an API description,
      # a docs build, client codegen, or a CI freshness check.
      #
      # @return [Hash{String => Hash}] every fragment, refs resolved
      # @raise [Error] if any fragment contains a ref that cannot be resolved
      #
      # @example
      #   File.write('schema.json', JSON.pretty_generate(Servus::Schema.compile_all))
      def compile_all
        keys.to_h { |key| [key, compile(fetch(key), context: "schema fragment #{key.inspect}")] }
      end

      # @return [Array<String>] registered keys, sorted
      def keys
        @registry.keys.sort
      end

      # Builds a +$ref+ pointing at a registered fragment.
      #
      # Prefer this over hand-writing ref strings — it is typo-proof in the
      # separator and prefix, which are the parts people get wrong.
      #
      # @param key [String, Symbol] the fragment key
      # @param path [Array<String, Symbol>] segments to walk within the fragment
      # @return [Hash] a +$ref+ hash
      #
      # @example
      #   Servus::Schema.ref('core', '$defs', 'amount')
      #   # => { "$ref" => "#/core/$defs/amount" }
      def ref(key, *path)
        { '$ref' => "#/#{[key, *path].join('/')}" }
      end

      # Compiles a schema, replacing every +$ref+ with the fragment it names.
      #
      # @param schema [Hash, nil] the authored schema
      # @param context [String, nil] label used in error messages, e.g.
      #   "Treasury::TransferGold::Service arguments schema"
      # @return [Hash, nil] the compiled schema, or nil if +schema+ was nil
      # @raise [Error] if any ref cannot be resolved
      def compile(schema, context: nil)
        return nil if schema.nil?

        Compiler.new(context: context).compile(schema)
      end

      # Clears the registry. Intended for test suites.
      #
      # @return [void]
      def reset!
        restore({}.freeze)
      end

      # Captures the registry state so a test can restore it afterwards.
      #
      # @return [Hash] an opaque snapshot for {restore}
      # @api private
      def snapshot
        @registry
      end

      # Restores a snapshot taken by {snapshot}.
      #
      # @param snapshot [Hash]
      # @return [void]
      # @api private
      def restore(snapshot)
        @mutex.synchronize { @registry = snapshot }
        cache.invalidate!
      end

      private

      # Writes a normalized fragment into the registry.
      #
      # @param key [String]
      # @param normalized [Hash] the normalized fragment
      # @return [Boolean] whether the registry actually changed
      # @api private
      def store(key, normalized)
        @mutex.synchronize do
          existing = @registry[key]
          return false if existing == normalized

          Support::Logger.log_schema_override(key) if existing
          @registry = @registry.merge(key => normalized).freeze
        end

        true
      end

      # @param key [String, Symbol]
      # @return [String]
      # @raise [InvalidKeyError]
      # @api private
      def normalize_key(key)
        key = key.to_s

        raise InvalidKeyError, 'schema fragment key cannot be blank' if key.strip.empty?

        if key.include?('/')
          raise InvalidKeyError, "schema fragment key #{key.inspect} cannot contain '/' — " \
                                 'it is the separator in $ref paths, so the key would be unreferenceable'
        end

        key
      end

      # @param key [String] the key, for the error message
      # @param fragment [Hash]
      # @return [ActiveSupport::HashWithIndifferentAccess] deeply frozen
      # @raise [ArgumentError] if the fragment is not a Hash
      # @api private
      def normalize_fragment(key, fragment)
        unless fragment.is_a?(Hash)
          raise ArgumentError, "schema fragment for #{key.inspect} must be a Hash, got #{fragment.class}"
        end

        deep_freeze(fragment.deep_dup.with_indifferent_access)
      end

      # @param value [Object]
      # @return [Object] the same value, frozen through nested hashes and arrays
      # @api private
      def deep_freeze(value)
        case value
        when Hash  then value.each_value { |v| deep_freeze(v) }.freeze
        when Array then value.each { |v| deep_freeze(v) }.freeze
        else value.freeze
        end
      end
    end
  end
end
