# frozen_string_literal: true

# Servus namespace
module Servus
  # Configuration settings for the Servus gem.
  #
  # Manages global configuration options including schema file locations.
  # Access the configuration via {Servus.config} or modify via {Servus.configure}.
  #
  # @example Customizing schema location
  #   Servus.configure do |config|
  #     config.schema_root = Rails.root.join('lib/schemas')
  #   end
  #
  # @see Servus.config
  # @see Servus.configure
  class Config
    # The root directory where schema files are located.
    #
    # Defaults to `Rails.root/app/schemas/services` in Rails applications,
    # or a relative path from the gem installation otherwise.
    #
    # @return [String] the schema root directory path
    attr_reader :schema_root

    # Whether to validate that all event handlers subscribe to events that are actually emitted by services.
    #
    # When enabled, raises an error on boot if handlers subscribe to non-existent events.
    # Helps catch typos and orphaned handlers.
    #
    # @return [Boolean] true to validate, false to skip validation
    attr_accessor :strict_event_validation

    # Initializes a new configuration with default values.
    #
    # @api private
    def initialize
      # Default to Rails.root if available, otherwise use current working directory
      @schema_root = File.join(root_path, 'app/schemas/services')
      @strict_event_validation = true
    end

    # Returns the full path to a service's schema file.
    #
    # Constructs the path by combining {#schema_root} with the service namespace
    # and schema type.
    #
    # @param service_namespace [String] underscored service namespace (e.g., "process_payment")
    # @param type [String] schema type ("arguments" or "result")
    # @return [String] full path to the schema JSON file
    #
    # @example
    #   config.schema_path_for("process_payment", "arguments")
    #   # => "/app/app/schemas/services/process_payment/arguments.json"
    def schema_path_for(service_namespace, type)
      File.join(schema_root.to_s, service_namespace, "#{type}.json")
    end

    # Returns the directory containing a service's schema files.
    #
    # @param service_namespace [String] underscored service namespace
    # @return [String] directory path for the service's schemas
    #
    # @example
    #   config.schema_dir_for("process_payment")
    #   # => "/app/app/schemas/services/process_payment"
    def schema_dir_for(service_namespace)
      File.join(schema_root.to_s, service_namespace)
    end

    private

    # Determines the application root path.
    #
    # @return [String] Rails.root in Rails apps, or gem's root directory otherwise
    # @api private
    def root_path
      if defined?(Rails) && Rails.respond_to?(:root)
        Rails.root
      else
        File.expand_path('../../..', __dir__)
      end
    end
  end

  # Returns the singleton configuration instance.
  #
  # @return [Servus::Config] the global configuration object
  #
  # @example
  #   Servus.config.schema_root
  #   # => "/app/app/schemas/services"
  def self.config
    @config ||= Config.new
  end

  # Yields the configuration for modification.
  #
  # @yieldparam config [Servus::Config] the configuration object to modify
  # @return [void]
  #
  # @example
  #   Servus.configure do |config|
  #     config.schema_root = Rails.root.join('custom/schemas')
  #   end
  def self.configure
    yield(config)
  end
end
