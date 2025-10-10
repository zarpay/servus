# frozen_string_literal: true

# Servus namespace
module Servus
  # Configuration class for Servus
  class Config
    # The directory where schemas are loaded from, can be set by the user
    attr_reader :schema_root

    def initialize
      # Default to Rails.root if available, otherwise use current working directory
      @schema_root = File.join(root_path, 'app/schemas/services')
    end

    # Returns the path for a specific service's schema
    #
    # @param service_namespace [String] the namespace of the service
    # @param type [String] the type of the schema (e.g., "arguments", "result")
    # @return [String] the path for the service's schema type
    def schema_path_for(service_namespace, type)
      File.join(schema_root.to_s, service_namespace, "#{type}.json")
    end

    # Returns the directory for a specific service
    #
    # @param service_namespace [String] the namespace of the service
    # @return [String] the directory for the service's schemas
    def schema_dir_for(service_namespace)
      File.join(schema_root.to_s, service_namespace)
    end

    private

    # Sets the schema root directory
    #
    # @param path [String] the new schema root directory
    def root_path
      if defined?(Rails) && Rails.respond_to?(:root)
        Rails.root
      else
        File.expand_path('../../..', __dir__)
      end
    end
  end

  # Singleton config instance
  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield(config)
  end
end
