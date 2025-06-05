# frozen_string_literal: true

module Servus
  module Support
    class Response
      attr_reader :data, :error

      def initialize(success, data, error)
        @success = success
        @data = data
        @error = error
      end

      def success?
        @success
      end
    end
  end
end
