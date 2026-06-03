# frozen_string_literal: true

module Servus
  # Encapsulates the result of an operation: either successful data or an error,
  # never both. Use {.success}/{.failure} from anywhere — inside a {Servus::Base}
  # service ({Servus::Base#success} / {Servus::Base#failure} delegate here) or
  # from plain Ruby code that wants the same success/failure shape.
  #
  # Use {#success?} to determine which path to take when handling results.
  #
  # @example Inside a service
  #   class MyService < Servus::Base
  #     def call
  #       return failure("Invalid amount") if @amount <= 0
  #
  #       success(transaction_id: charge.id)
  #     end
  #   end
  #
  # @example Outside a service
  #   def import_rows(rows)
  #     return Servus::Result.failure("no rows") if rows.empty?
  #
  #     Servus::Result.success(imported: rows.count)
  #   end
  #
  # @example Handling a result
  #   result = import_rows(rows)
  #   if result.success?
  #     puts "Imported: #{result.data.imported}"
  #   else
  #     puts "Error: #{result.error.message}"
  #   end
  class Result
    # @return [Object, nil] the data returned on success (nil on failure unless
    #   structured failure data was attached via {.failure})
    attr_reader :data

    # @return [Servus::Support::Errors::ServiceError, nil] the error returned on
    #   failure (nil on success)
    attr_reader :error

    # Builds a successful result wrapping the given data.
    #
    # @param data [Object, nil] the data to return (Hashes are wrapped in a
    #   {Servus::Support::DataObject} for accessor-style access)
    # @return [Servus::Result]
    #
    # @example
    #   Servus::Result.success(user_id: 123, status: "active")
    def self.success(data = nil)
      new(true, data, nil)
    end

    # Builds a failure result with an error.
    #
    # @param message [String, nil] error message; falls back to the error type's
    #   default when nil
    # @param data [Object, nil] optional structured data to attach to the failure
    # @param type [Class] error class to instantiate (must inherit from
    #   {Servus::Support::Errors::ServiceError})
    # @return [Servus::Result]
    #
    # @example Default error type
    #   Servus::Result.failure("User not found")
    #
    # @example Custom error type
    #   Servus::Result.failure("Bad input", type: Servus::Support::Errors::BadRequestError)
    #
    # @example With structured failure data
    #   Servus::Result.failure("Card declined", data: { reason: "insufficient_funds" })
    def self.failure(message = nil, data: nil, type: Servus::Support::Errors::ServiceError)
      new(false, data, type.new(message))
    end

    # @note Prefer {.success} or {.failure}. Direct construction is supported
    #   for advanced cases (e.g. wrapping an existing error instance).
    #
    # @param success [Boolean] true for successful results, false for failures
    # @param data [Object, nil] the result data (nil for failures by default)
    # @param error [Servus::Support::Errors::ServiceError, nil] the error
    #   (nil for successes)
    def initialize(success, data, error)
      @success = success
      @data = Servus::Support::DataObject.wrap(data)
      @error = error
    end

    # @return [Boolean] true if the operation succeeded, false if it failed
    def success?
      @success
    end

    # @return [Boolean] true if the operation failed, false if it succeeded
    def failure?
      !@success
    end
  end
end
