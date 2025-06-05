# frozen_string_literal: true

require "spec_helper"

RSpec.describe Servus::Support::Validator do
  # Create a test service class
  module SchemaValidationTest
    class Service < Servus::Base
      def initialize(name:, age:)
        @name = name
        @age = age
      end

      def call
        success({
                  id: 123,
                  name: @name,
                  age: @age
                })
      end
    end

    class ServiceWithNonPrimitiveArguments < Servus::Base
      def initialize(user:)
        @user = user
      end

      def call
        success({ user: @user })
      end
    end
  end

  context "with inline schema" do
    before { described_class.clear_cache! }

    after do
      if defined?(SchemaValidationTest::Service::ARGUMENTS_SCHEMA)
        SchemaValidationTest::Service.send(:remove_const,
                                           :ARGUMENTS_SCHEMA)
      end
      if defined?(SchemaValidationTest::Service::RESULT_SCHEMA)
        SchemaValidationTest::Service.send(:remove_const,
                                           :RESULT_SCHEMA)
      end
    end

    describe ".load_schema" do
      context "when inline schema exists" do
        before do
          module SchemaValidationTest
            class Service
              ARGUMENTS_SCHEMA = {
                type: "object",
                required: %w[name age],
                properties: { name: { type: "string" }, age: { type: "integer" } }
              }.freeze
            end
          end
        end

        it "loads and returns the schema" do
          schema = described_class.load_schema(SchemaValidationTest::Service, "arguments")

          expect(schema).to be_a(Hash)
          expect(schema[:type]).to eq("object")
          expect(schema[:required]).to include("name", "age")
        end

        it "caches the schema" do
          # Load once
          described_class.load_schema(SchemaValidationTest::Service, "arguments")

          # Modify the inline schema
          SchemaValidationTest::Service::ARGUMENTS_SCHEMA = {
            type: "object",
            required: [ "modified" ]
          }.freeze
          # Load again - should return cached version
          schema = described_class.load_schema(SchemaValidationTest::Service, "arguments")

          expect(schema[:required]).to include("name", "age")
          expect(schema[:required]).not_to include("modified")
        end
      end

      context "when inline schema does not exist" do
        it "returns nil" do
          schema = described_class.load_schema(SchemaValidationTest::Service, "nonexistent")

          expect(schema).to be_nil
        end

        it "caches the nil result" do
          expect(File).to receive(:exist?).once.and_call_original

          # Load twice
          described_class.load_schema(SchemaValidationTest::Service, "nonexistent")
          described_class.load_schema(SchemaValidationTest::Service, "nonexistent")
        end
      end
    end

    describe ".validate_arguments" do
      context "when no schema exists" do
        it "returns true without validation" do
          expect(described_class.validate_arguments!(SchemaValidationTest::Service, { any: "args" })).to eq(true)
        end
      end

      context "when schema exists" do
        before do
          module SchemaValidationTest
            class Service
              ARGUMENTS_SCHEMA = {
                type: "object",
                required: [ "name" ],
                properties: {
                  name: { type: "string" },
                  age: { type: "integer", minimum: 18 }
                }
              }.freeze
            end
          end
        end

        it "returns true for valid arguments" do
          expect(described_class.validate_arguments!(SchemaValidationTest::Service,
                                                     { name: "John", age: 25 })).to eq(true)
        end

        it "raises ValidationError for missing required field" do
          expect do
            described_class.validate_arguments!(SchemaValidationTest::Service, { age: 25 })
          end.to raise_error(Servus::Base::ValidationError, /required property of 'name'/)
        end

        it "raises ValidationError for invalid field type" do
          expect do
            described_class.validate_arguments!(SchemaValidationTest::Service, { name: "John", age: "twenty" })
          end.to raise_error(Servus::Base::ValidationError, /did not match the following type: integer/)
        end

        it "raises ValidationError for out of range value" do
          expect do
            described_class.validate_arguments!(SchemaValidationTest::Service, { name: "John", age: 17 })
          end.to raise_error(Servus::Base::ValidationError, /did not have a minimum value of 18/)
        end
      end
    end

    describe ".validate_result" do
      let(:success_result) { Servus::Support::Response.new(true, { id: 123 }, nil) }
      let(:error_result) { Servus::Support::Response.new(false, nil, "Error") }

      context "when no schema exists" do
        it "returns the result unchanged" do
          expect(described_class.validate_result!(SchemaValidationTest::Service, success_result)).to eq(success_result)
        end
      end

      context "when schema exists" do
        before do
          module SchemaValidationTest
            class Service
              RESULT_SCHEMA = {
                type: "object",
                required: %w[id status],
                properties: {
                  id: { type: "integer" },
                  status: { type: "string" }
                }
              }.freeze
            end
          end
        end

        it "returns error results unchanged without validation" do
          expect(described_class.validate_result!(SchemaValidationTest::Service, error_result)).to eq(error_result)
        end

        it "returns the success result unchanged if valid" do
          valid_result = Servus::Support::Response.new(true, { id: 123, status: "complete" }, nil)
          expect(described_class.validate_result!(SchemaValidationTest::Service, valid_result)).to eq(valid_result)
        end

        it "raises ValidationError if success result has invalid structure" do
          expect do
            described_class.validate_result!(SchemaValidationTest::Service, success_result)
          end.to raise_error(Servus::Base::ValidationError, /did not contain a required property of 'status'/)
        end

        it "raises ValidationError if success result has invalid types" do
          invalid_result = Servus::Support::Response.new(true, { id: "123", status: "complete" }, nil)
          expect do
            described_class.validate_result!(SchemaValidationTest::Service, invalid_result)
          end.to raise_error(Servus::Base::ValidationError, /did not match the following type: integer/)
        end
      end

      context "when non-primitive values are passed" do
        class TestUserObject
          attr_reader :id, :name, :age

          def initialize(id:, name:, age:)
            @id = id
            @age = age
            @name = name
          end
        end

        before do
          module SchemaValidationTest
            class ServiceWithNonPrimitiveArguments
              RESULT_SCHEMA = {
                type: "object",
                required: [ "user" ],
                properties: {
                  user: {
                    type: "object",
                    properties: {
                      id: { type: "string" },
                      age: { type: "integer" },
                      name: { type: "string" }
                    }
                  }
                }
              }.freeze
            end
          end
        end

        it "returns the success result unchanged if valid" do
          user = TestUserObject.new(id: "123e4567-e89b-12d3-a456-426614174000", name: "John Doe", age: 30)

          valid_result = Servus::Support::Response.new(true, { user: user }, nil)

          expect(described_class.validate_result!(SchemaValidationTest::ServiceWithNonPrimitiveArguments,
                                                  valid_result)).to eq(valid_result)
        end

        it "raises ValidationError if success result has invalid types" do
          user = TestUserObject.new(id: 1, name: "John Doe", age: 30) # Invalid UUID (string)
          invalid_result = Servus::Support::Response.new(true, { user: user }, nil)
          expect do
            described_class.validate_result!(SchemaValidationTest::ServiceWithNonPrimitiveArguments, invalid_result)
          end.to raise_error(Servus::Base::ValidationError, /did not match the following type: string/)
        end
      end
    end

    describe ".clear_cache!" do
      before do
        module SchemaValidationTest
          class Service
            RESULT_SCHEMA = { type: "object" }.freeze
          end
        end
        described_class.load_schema(SchemaValidationTest::Service, "arguments")
      end

      it "clears the schema cache" do
        # Load once (should use cache)
        described_class.load_schema(SchemaValidationTest::Service, "arguments")

        # Check cache
        expect(described_class.cache).not_to be_empty

        # Clear cache
        described_class.clear_cache!

        # Check cache is cleared
        expect(described_class.cache).to be_empty
      end
    end
  end

  context "with file schema" do
    # Set up temp directory for test schemas
    let(:schema_dir) { Servus.config.schema_dir_for("schema_validation_test") }

    before do
      # Create schema directory if it doesn't exist
      FileUtils.mkdir_p(schema_dir)
      described_class.clear_cache!
    end

    after do
      # Clean up test schemas
      FileUtils.rm_rf(schema_dir)
    end

    describe ".load_schema" do
      context "when schema file exists" do
        before do
          File.write(
            "#{schema_dir}/arguments.json",
            {
              type: "object",
              required: %w[name age],
              properties: { name: { type: "string" }, age: { type: "integer" } }
            }.to_json
          )
        end

        it "loads and returns the schema" do
          schema = described_class.load_schema(SchemaValidationTest::Service, "arguments")

          expect(schema).to be_a(Hash)
          expect(schema["type"]).to eq("object")
          expect(schema["required"]).to include("name", "age")
        end

        it "caches the schema" do
          # Load once
          described_class.load_schema(SchemaValidationTest::Service, "arguments")

          # Modify the file
          File.write(
            "#{schema_dir}/arguments.json",
            {
              type: "object",
              required: [ "modified" ]
            }.to_json
          )

          # Load again - should return cached version
          schema = described_class.load_schema(SchemaValidationTest::Service, "arguments")

          expect(schema["required"]).to include("name", "age")
          expect(schema["required"]).not_to include("modified")
        end
      end

      context "when schema file does not exist" do
        it "returns nil" do
          schema = described_class.load_schema(SchemaValidationTest::Service, "nonexistent")

          expect(schema).to be_nil
        end

        it "caches the nil result" do
          expect(File).to receive(:exist?).once.and_call_original

          # Load twice
          described_class.load_schema(SchemaValidationTest::Service, "nonexistent")
          described_class.load_schema(SchemaValidationTest::Service, "nonexistent")
        end
      end
    end

    describe ".validate_arguments" do
      context "when no schema exists" do
        it "returns true without validation" do
          expect(described_class.validate_arguments!(SchemaValidationTest::Service, { any: "args" })).to eq(true)
        end
      end

      context "when schema exists" do
        before do
          File.write(
            "#{schema_dir}/arguments.json",
            {
              type: "object",
              required: [ "name" ],
              properties: {
                name: { type: "string" },
                age: { type: "integer", minimum: 18 }
              }
            }.to_json
          )
        end

        it "returns true for valid arguments" do
          expect(described_class.validate_arguments!(SchemaValidationTest::Service,
                                                     { name: "John", age: 25 })).to eq(true)
        end

        it "raises ValidationError for missing required field" do
          expect do
            described_class.validate_arguments!(SchemaValidationTest::Service, { age: 25 })
          end.to raise_error(Servus::Base::ValidationError, /required property of 'name'/)
        end

        it "raises ValidationError for invalid field type" do
          expect do
            described_class.validate_arguments!(SchemaValidationTest::Service, { name: "John", age: "twenty" })
          end.to raise_error(Servus::Base::ValidationError, /did not match the following type: integer/)
        end

        it "raises ValidationError for out of range value" do
          expect do
            described_class.validate_arguments!(SchemaValidationTest::Service, { name: "John", age: 17 })
          end.to raise_error(Servus::Base::ValidationError, /did not have a minimum value of 18/)
        end
      end
    end

    describe ".validate_result" do
      let(:success_result) { Servus::Support::Response.new(true, { id: 123 }, nil) }
      let(:error_result) { Servus::Support::Response.new(false, nil, "Error") }

      context "when no schema exists" do
        it "returns the result unchanged" do
          expect(described_class.validate_result!(SchemaValidationTest::Service, success_result)).to eq(success_result)
        end
      end

      context "when schema exists" do
        before do
          File.write(
            "#{schema_dir}/result.json", {
              type: "object",
              required: %w[id status],
              properties: {
                id: { type: "integer" },
                status: { type: "string" }
              }
            }.to_json
          )
        end

        it "returns error results unchanged without validation" do
          expect(described_class.validate_result!(SchemaValidationTest::Service, error_result)).to eq(error_result)
        end

        it "returns the success result unchanged if valid" do
          valid_result = Servus::Support::Response.new(true, { id: 123, status: "complete" }, nil)
          expect(described_class.validate_result!(SchemaValidationTest::Service, valid_result)).to eq(valid_result)
        end

        it "raises ValidationError if success result has invalid structure" do
          expect do
            described_class.validate_result!(SchemaValidationTest::Service, success_result)
          end.to raise_error(Servus::Base::ValidationError, /did not contain a required property of 'status'/)
        end

        it "raises ValidationError if success result has invalid types" do
          invalid_result = Servus::Support::Response.new(true, { id: "123", status: "complete" }, nil)
          expect do
            described_class.validate_result!(SchemaValidationTest::Service, invalid_result)
          end.to raise_error(Servus::Base::ValidationError, /did not match the following type: integer/)
        end
      end

      context "when non-primitive values are passed" do
        # rubocop:disable Style/Documentation, Lint/ConstantDefinitionInBlock
        class TestUserObject
          attr_reader :id, :name, :age # leftovers:keep

          def initialize(id:, name:, age:)
            @id = id
            @age = age
            @name = name
          end
        end
        # rubocop:enable Style/Documentation, Lint/ConstantDefinitionInBlock

        before do
          File.write(
            "#{schema_dir}/result.json",
            {
              type: "object",
              required: [ "user" ],
              properties: {
                user: {
                  type: "object",
                  properties: {
                    id: { type: "string" },
                    age: { type: "integer" },
                    name: { type: "string" }
                  }
                }
              }
            }.to_json
          )
        end

        it "returns the success result unchanged if valid" do
          user = TestUserObject.new(id: "123e4567-e89b-12d3-a456-426614174000", name: "John Doe", age: 30)

          valid_result = Servus::Support::Response.new(true, { user: user }, nil)

          expect(described_class.validate_result!(
            SchemaValidationTest::ServiceWithNonPrimitiveArguments,
            valid_result)
          ).to eq(valid_result)
        end

        it "raises ValidationError if success result has invalid types" do
          user = TestUserObject.new(id: 1, name: "John Doe", age: 30) # Invalid UUID (string)
          invalid_result = Servus::Support::Response.new(true, { user: user }, nil)
          expect do
            described_class.validate_result!(SchemaValidationTest::ServiceWithNonPrimitiveArguments, invalid_result)
          end.to raise_error(Servus::Base::ValidationError, /did not match the following type: string/)
        end
      end
    end

    describe ".clear_cache!" do
      before do
        File.write("#{schema_dir}/arguments.json", { type: "object" }.to_json)
        described_class.load_schema(SchemaValidationTest::Service, "arguments")
      end

      it "clears the schema cache" do
        # Load once (should use cache)
        described_class.load_schema(SchemaValidationTest::Service, "arguments")

        # Check cache
        expect(described_class.cache).not_to be_empty

        # Clear cache
        described_class.clear_cache!

        # Check cache is cleared
        expect(described_class.cache).to be_empty
      end
    end
  end
end
