# frozen_string_literal: true

module Servus
  module Extensions
    module Lazily
      # Error classes for lazy record resolution.
      #
      # These errors are raised when lazy resolution fails, such as when
      # a required record reference is nil.
      module Errors
        # Base error class for all lazily extension errors.
        #
        # All lazy resolution errors inherit from this class for easy rescue handling.
        class LazilyError < StandardError; end

        # Raised when a lazily-resolved record reference is nil.
        #
        # This occurs when a service declares +lazily :user, finds: User+ but
        # receives +user: nil+. A nil reference is always a bug at the call site.
        #
        # @example
        #   class MyService < Servus::Base
        #     lazily :user, finds: User
        #
        #     def initialize(user:)
        #       @user = user
        #     end
        #
        #     def call
        #       user # => raises NotFoundError if @user is nil
        #     end
        #   end
        class NotFoundError < LazilyError; end
      end
    end
  end
end
