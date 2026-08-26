# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'rails/generators'
require 'generators/servus/service/service_generator'

RSpec.describe Servus::Generators::ServiceGenerator do
  let(:tmp_root) { Dir.mktmpdir('servus-generator-spec') }

  around do |example|
    original = Servus.config.tests_dir
    example.run
  ensure
    Servus.config.tests_dir = original
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

  it 'scaffolds the schema DSL in the generated service' do
    invoke('treasury/transfer_gold', 'from_account')

    contents = File.read(File.join(tmp_root, 'app/services/treasury/transfer_gold/service.rb'))

    expect(contents).to include('schema')
  end
end
