# frozen_string_literal: true

module Servus
  module Schema
    # Walks a path of literal keys into a registered schema fragment.
    #
    # This is the single addressing implementation behind both
    # {Servus::Schema.fetch} and +$ref+ resolution, so a path that misses reads
    # the same whether application code asked for it directly or a ref led there.
    #
    # Segments are literal hash keys, not JSON Pointer tokens — there is no
    # +~0+/+~1+ unescaping and no array indexing.
    #
    # @see Servus::Schema.fetch
    # @see Servus::Schema::Ref
    # @api private
    module Path
      class << self
        # Walks +path+ into +fragment+.
        #
        # @param fragment [Hash] the registered fragment
        # @param key [String] the fragment key, for the error message
        # @param path [Array<String>] segments to walk
        # @return [Object] the value at the path, or the fragment if path is empty
        # @raise [RefNotFoundError] if a segment is not present
        def walk(fragment, key, path)
          path.reduce(fragment) do |current, segment|
            unless current.is_a?(Hash) && current.key?(segment)
              raise RefNotFoundError, message_for(key, path, segment, current)
            end

            current[segment]
          end
        end

        private

        # @param key [String] the fragment key
        # @param path [Array<String>] the full path being walked
        # @param segment [String] the segment that was not found
        # @param current [Object] the node the walk failed at
        # @return [String]
        # @api private
        def message_for(key, path, segment, current)
          "#{path.join('/').inspect} could not be resolved in schema fragment #{key.inspect}: " \
            "#{segment.inspect} is not present.#{available_in(current)}"
        end

        # @param current [Object] the node the walk failed at
        # @return [String] a clause describing what was there instead
        # @api private
        def available_in(current)
          return " #{current.class} is not a Hash, so it has no keys to walk into." unless current.is_a?(Hash)

          " Available keys: #{current.keys.map(&:to_s).sort.map(&:inspect).join(', ')}."
        end
      end
    end
  end
end
