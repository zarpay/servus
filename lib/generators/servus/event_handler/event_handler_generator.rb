# frozen_string_literal: true

module Servus
  module Generators
    # Rails generator for creating Servus event handlers.
    #
    # Generates an event handler class and spec file.
    #
    # @example Generate an event handler
    #   rails g servus:event_handler user_created
    #
    # @example Generated files
    #   app/events/user_created_handler.rb
    #   spec/app/events/user_created_handler_spec.rb
    #
    # @see https://guides.rubyonrails.org/generators.html
    class EventHandlerGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      class_option :no_docs, type: :boolean,
                             default: false,
                             desc: 'Skip documentation comments in generated files'

      # Creates the event handler and spec files.
      #
      # @return [void]
      def create_handler_file
        template 'handler.rb.erb', handler_path
        template 'handler_spec.rb.erb', handler_spec_path
      end

      private

      # Returns the path for the handler file.
      #
      # @return [String] handler file path
      # @api private
      def handler_path
        File.join(Servus.config.events_dir, "#{file_name}_handler.rb")
      end

      # Returns the path for the handler spec file.
      #
      # @return [String] spec file path
      # @api private
      def handler_spec_path
        File.join('spec', Servus.config.events_dir, "#{file_name}_handler_spec.rb")
      end

      # Returns the handler class name.
      #
      # @return [String] handler class name
      # @api private
      def handler_class_name
        "#{class_name}Handler"
      end
    end
  end
end
