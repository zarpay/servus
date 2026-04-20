# frozen_string_literal: true

module Servus
  module Generators
    # Rails generator for creating Servus guards.
    #
    # Generates a guard class and spec file.
    #
    # @example Generate a guard
    #   rails g servus:guard sufficient_balance
    #
    # @example Generated files
    #   app/guards/sufficient_balance_guard.rb
    #   spec/guards/sufficient_balance_guard_spec.rb
    #
    # @see https://guides.rubyonrails.org/generators.html
    class GuardGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      class_option :no_docs, type: :boolean,
                             default: false,
                             desc: 'Skip documentation comments in generated files'

      # Creates the guard and spec files.
      #
      # @return [void]
      def create_guard_file
        template 'guard.rb.erb', guard_path
        template 'guard_spec.rb.erb', guard_spec_path
      end

      private

      # Returns the path for the guard file.
      #
      # @return [String] guard file path
      # @api private
      def guard_path
        File.join(Servus.config.guards_dir, "#{file_name}_guard.rb")
      end

      # Returns the path for the guard spec file.
      #
      # @return [String] spec file path
      # @api private
      def guard_spec_path
        File.join(Servus.config.tests_dir, Servus.config.guards_dir, "#{file_name}_guard_spec.rb")
      end

      # Returns the guard class name.
      #
      # @return [String] guard class name
      # @api private
      def guard_class_name
        "#{class_name}Guard"
      end

      # Returns the enforce method name.
      #
      # @return [String] enforce method name
      # @api private
      def enforce_method_name
        "enforce_#{file_name}!"
      end

      # Returns the check method name.
      #
      # @return [String] check method name
      # @api private
      def check_method_name
        "check_#{file_name}?"
      end
    end
  end
end
