# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'rails/generators'
require 'generators/servus/service/service_generator'

RSpec.describe Servus::Generators::ServiceGenerator do
  let(:tmp_root) { Dir.mktmpdir('servus-generator-spec') }

  around do |example|
    original_tests = Servus.config.tests_dir
    original_services = Servus.config.services_dir
    example.run
  ensure
    Servus.config.tests_dir = original_tests
    Servus.config.services_dir = original_services
    FileUtils.rm_rf(tmp_root)
  end

  def invoke(name, *parameters)
    described_class.start([name, *parameters], destination_root: tmp_root)
  end

  it 'places the spec under spec/ by default' do
    invoke('treasury/transfer_gold', 'from_account')

    expect(File).to exist(File.join(tmp_root, 'spec/services/treasury/transfer_gold/service_spec.rb'))
  end

  it 'honours config.tests_dir when placing the spec' do
    Servus.config.tests_dir = 'test'

    invoke('treasury/transfer_gold', 'from_account')

    expect(File).to exist(File.join(tmp_root, 'test/services/treasury/transfer_gold/service_spec.rb'))
    expect(File).not_to exist(File.join(tmp_root, 'spec/services/treasury/transfer_gold/service_spec.rb'))
  end

  it 'generates the service class' do
    invoke('treasury/transfer_gold', 'from_account')

    expect(File).to exist(File.join(tmp_root, 'app/services/treasury/transfer_gold/service.rb'))
  end

  it 'honours config.services_dir when placing the service' do
    Servus.config.services_dir = 'app/domain'

    invoke('treasury/transfer_gold', 'from_account')

    expect(File).to exist(File.join(tmp_root, 'app/domain/treasury/transfer_gold/service.rb'))
    expect(File).not_to exist(File.join(tmp_root, 'app/services/treasury/transfer_gold/service.rb'))
  end

  describe 'the generated schema declaration' do
    subject(:contents) do
      invoke('treasury/transfer_gold', 'from_account', 'gold_dragons')
      File.read(File.join(tmp_root, 'app/services/treasury/transfer_gold/service.rb'))
    end

    # Commented-out scaffolding gets skipped. Real code gets filled in.
    it 'is live code rather than a comment block' do
      expect(contents).to match(/^\s{4}schema\(/)
    end

    it 'declares both an arguments and a result schema' do
      expect(contents).to include('arguments: {')
      expect(contents).to include('result: {')
    end

    it 'requires every declared parameter' do
      expect(contents).to include('required: %w[from_account gold_dragons]')
    end

    it 'lists every parameter as a property' do
      expect(contents).to match(/from_account: \{/)
      expect(contents).to match(/gold_dragons: \{/)
    end

    it 'still generates a schema when docs are skipped' do
      described_class.start(
        ['treasury/transfer_gold', 'from_account', '--no-docs'],
        destination_root: tmp_root
      )
      written = File.read(File.join(tmp_root, 'app/services/treasury/transfer_gold/service.rb'))

      expect(written).to match(/^\s{4}schema\(/)
    end

    it 'produces a service whose schema Servus accepts' do
      invoke('treasury/transfer_gold', 'from_account')
      written = File.read(File.join(tmp_root, 'app/services/treasury/transfer_gold/service.rb'))

      # Strip the module nesting and evaluate the class body against Servus::Base
      # to prove the generated declaration is valid, not merely well-shaped text.
      body = written[/class Service < Servus::Base\n(.*)\n  end\nend/m, 1]
      klass = Class.new(Servus::Base)
      expect { klass.class_eval(body) }.not_to raise_error
      expect(klass.arguments_schema['required']).to eq(['from_account'])
    end
  end

  it 'indents every instance variable assignment inside initialize' do
    invoke('treasury/transfer_gold', 'from_account', 'to_account')

    contents = File.read(File.join(tmp_root, 'app/services/treasury/transfer_gold/service.rb'))
    body = contents[/def initialize.*?\n(.*?)\n    end/m, 1]

    expect(body.lines.map { |line| line[/\A */].length }.uniq).to eq([6])
  end

  describe 'a service generated with no parameters' do
    subject(:contents) do
      invoke('treasury/reconcile')
      File.read(File.join(tmp_root, 'app/services/treasury/reconcile/service.rb'))
    end

    it 'declares an empty required list rather than omitting it' do
      expect(contents).to include('required: []')
    end
  end
end
