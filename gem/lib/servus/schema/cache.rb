# frozen_string_literal: true

module Servus
  module Schema
    # Memoized +$ref+ resolutions, plus the generation counter that invalidates
    # everything derived from them.
    #
    # Entries are keyed by ref string and hold the resolved *target* of that
    # ref, before any sibling properties are merged over it. That is what makes
    # a single entry safe to share across every site that uses the ref: the
    # target depends only on the ref string and the registry contents, and
    # callers apply their own siblings afterwards with +Hash#merge+, which
    # returns a new hash and never mutates the cached one.
    #
    # The generation counter lets consumers that build on compiled schemas —
    # {Servus::Base}, {Servus::Event} — memoize alongside the generation they
    # compiled under and rebuild when it moves, with no dependency tracking.
    #
    # @see Servus::Schema
    # @see Servus::Schema::Compiler
    # @api private
    class Cache
      # Monotonic counter, advanced by {#invalidate!}.
      #
      # @return [Integer]
      attr_reader :generation

      def initialize
        @entries = {}
        @generation = 0
        @mutex = Mutex.new
      end

      # Returns the memoized resolution of +ref+, computing it on a miss.
      #
      # A raising block leaves no entry behind, so a ref that failed part way
      # through resolution is never cached in a half-built state.
      #
      # @param ref [String] the ref string
      # @yieldreturn [Object] the resolved target, computed on a miss
      # @return [Object] the resolved target
      def resolve(ref)
        cached = @entries[ref]
        return cached unless cached.nil?

        resolved = yield
        @mutex.synchronize { @entries[ref] = resolved }
        resolved
      end

      # Discards every memoized resolution and advances {#generation}.
      #
      # @return [void]
      def invalidate!
        @mutex.synchronize do
          @entries = {}
          @generation += 1
        end
      end

      # Number of memoized resolutions. Used by specs to assert that a repeated
      # ref is expanded once rather than once per occurrence.
      #
      # @return [Integer]
      def size
        @entries.size
      end
    end
  end
end
