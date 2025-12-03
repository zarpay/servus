# frozen_string_literal: true

module Servus
  # Testing utilities for Servus services.
  #
  # This module provides helpers for extracting example values from JSON schemas
  # to use in tests, making it easier to create test fixtures without manually
  # maintaining separate factory files.
  #
  # @see Servus::Testing::ExampleBuilders
  # @see Servus::Testing::ExampleExtractor
  module Testing
  end
end

require_relative 'testing/example_extractor'
require_relative 'testing/example_builders'
require_relative 'testing/event_helpers'
