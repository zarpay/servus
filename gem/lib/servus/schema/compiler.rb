# frozen_string_literal: true

module Servus
  module Schema
    # Resolves +$ref+ pointers in a schema against the {Servus::Schema} registry,
    # producing a self-contained schema with no refs left in it.
    #
    # One instance per compile. The instance carries the cycle-detection state
    # and the context label used in error messages; the memo it consults is
    # process-wide and lives on {Servus::Schema}.
    #
    # == Sibling properties
    #
    # Keys alongside a +$ref+ override the resolved target:
    #
    #   { '$ref' => '#/core/$defs/amount', 'description' => 'Fee charged' }
    #
    # This is a template-and-override reading, which is what makes shared
    # fragments usable in practice — you take the shape and re-describe it for
    # the site that uses it. Note that it *differs* from JSON Schema 2019-09 and
    # later, where properties beside a +$ref+ are an additional subschema
    # applied as an intersection rather than an override.
    #
    # Siblings are compiled independently and merged *onto* an already-resolved
    # target, rather than merged first and resolved after. That ordering is what
    # makes the target cacheable: the memo holds a value that does not depend on
    # the call site.
    #
    # @see Servus::Schema
    # @see Servus::Schema::Ref
    class Compiler
      # Maximum structural nesting depth before {DepthExceededError} is raised.
      #
      # This is a runaway guard for pathological input, not a cycle check —
      # cycles are caught exactly by {#resolve_ref}'s visited set, however deep
      # or shallow they are. Keeping the two separate means a legitimately deep
      # acyclic schema compiles instead of being misreported as circular.
      MAX_DEPTH = 100

      # Keys stripped from a fragment when it is spliced into another schema.
      #
      # +json-schema+ resolves a nested +$schema+ against its registered
      # validators and raises +JSON::Schema::SchemaError+ when it does not
      # recognize the URI — at any position in the document, not just the root.
      # Fragments authored as standalone documents routinely carry these, so
      # they are dropped on splice rather than left to blow up at validation time.
      #
      # @see https://github.com/voxpupuli/json-schema
      METADATA_KEYS = %w[$schema $id id].freeze

      # @param context [String, nil] label for the schema being compiled, used
      #   in error messages, e.g. "Treasury::TransferGold::Service arguments schema"
      def initialize(context: nil)
        @context = context
        @path = []
      end

      # Compiles a schema, replacing every +$ref+ with the fragment it names.
      #
      # @param schema [Object] the authored schema
      # @return [Object] the compiled schema
      # @raise [Error] if any ref cannot be resolved
      def compile(schema)
        resolve(schema, 0)
      end

      private

      # Recursively resolves a node.
      #
      # @param node [Object]
      # @param depth [Integer] current structural nesting depth
      # @return [Object]
      # @api private
      def resolve(node, depth)
        raise_with_context(depth_error) if depth > MAX_DEPTH

        case node
        when Hash  then resolve_hash(node, depth)
        when Array then node.map { |item| resolve(item, depth + 1) }
        else node
        end
      end

      # @param node [Hash]
      # @param depth [Integer]
      # @return [Hash]
      # @api private
      def resolve_hash(node, depth)
        return resolve_ref_node(node, depth) if node.key?('$ref') || node.key?(:$ref)

        node.transform_values { |value| resolve(value, depth + 1) }
      end

      # Resolves a node carrying a +$ref+, merging sibling keys over the target.
      #
      # @param node [Hash]
      # @param depth [Integer]
      # @return [Hash]
      # @api private
      def resolve_ref_node(node, depth)
        target = resolve_ref(node['$ref'] || node[:$ref])
        siblings = node.reject { |key, _| key.to_s == '$ref' }

        siblings.empty? ? target : target.merge(resolve_hash(siblings, depth))
      end

      # Resolves a single ref to its target, guarding against cycles.
      #
      # @param value [Object] the raw +$ref+ value
      # @return [Object] the resolved target
      # @raise [Error]
      # @api private
      def resolve_ref(value)
        ref = with_context { Ref.parse(value) }

        raise_with_context(circular_error(ref)) if @path.include?(ref.value)

        @path.push(ref.value)
        begin
          Schema.cache.resolve(ref.value) { expand(ref) }
        ensure
          @path.pop
        end
      end

      # Looks a ref's target up in the registry and resolves it in turn.
      #
      # @param ref [Ref]
      # @return [Object]
      # @api private
      def expand(ref)
        target = with_context(ref) { Schema.fetch(ref.key, *ref.segments) }

        strip_metadata(resolve(target, 0))
      end

      # Removes document-level metadata from a spliced fragment.
      #
      # @param node [Object]
      # @return [Object]
      # @api private
      def strip_metadata(node)
        return node unless node.is_a?(Hash)
        return node unless node.keys.map(&:to_s).intersect?(METADATA_KEYS)

        node.reject { |key, _| METADATA_KEYS.include?(key.to_s) }
      end

      # Runs a block, re-raising any schema error with this compile's context.
      #
      # {Ref} and {Servus::Schema} raise where the problem is detected and know
      # nothing about which service or ref chain led there. This attaches that.
      #
      # @param ref [Ref, nil]
      # @yield the work that might raise
      # @return [Object] the block's value
      # @api private
      def with_context(ref = nil)
        yield
      rescue Error => e
        raise_with_context(e, ref)
      end

      # @param error [Error]
      # @param ref [Ref, nil]
      # @raise [Error] always
      # @api private
      def raise_with_context(error, ref = nil)
        raise error.with_context(
          ref: ref&.value,
          resolution_path: @path.dup,
          context: @context
        )
      end

      # @param ref [Ref]
      # @return [CircularReferenceError]
      # @api private
      def circular_error(ref)
        CircularReferenceError.new(
          "circular $ref detected: #{(@path + [ref.value]).join(' -> ')}",
          ref: ref.value
        )
      end

      # @return [DepthExceededError]
      # @api private
      def depth_error
        DepthExceededError.new(
          "schema nests more than #{MAX_DEPTH} levels deep. This is a runaway guard — " \
          'if the schema is legitimately this deep, flatten it into registered fragments.'
        )
      end
    end
  end
end
