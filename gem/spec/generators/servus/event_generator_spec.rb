# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'rails/generators'
require 'generators/servus/event/event_generator'

RSpec.describe Servus::Generators::EventGenerator do
  let(:tmp_root) { Dir.mktmpdir('servus-generator-spec') }

  around do |example|
    original = Servus.config.tests_dir
    example.run
  ensure
    Servus.config.tests_dir = original
    FileUtils.rm_rf(tmp_root)
  end

  def invoke(name)
    described_class.start([name], destination_root: tmp_root)
  end

  it 'generates the event class with _event suffix' do
    invoke('gold_transferred')

    expect(File).to exist(File.join(tmp_root, 'app/events/gold_transferred_event.rb'))
  end

  it 'places the spec under spec/ by default' do
    invoke('gold_transferred')

    expect(File).to exist(File.join(tmp_root, 'spec/app/events/gold_transferred_event_spec.rb'))
  end

  it 'honours config.tests_dir when placing the spec' do
    Servus.config.tests_dir = 'test'

    invoke('gold_transferred')

    expect(File).to exist(File.join(tmp_root, 'test/app/events/gold_transferred_event_spec.rb'))
    expect(File).not_to exist(File.join(tmp_root, 'spec/app/events/gold_transferred_event_spec.rb'))
  end

  it 'generates a class inheriting from Servus::Event' do
    invoke('gold_transferred')

    content = File.read(File.join(tmp_root, 'app/events/gold_transferred_event.rb'))
    expect(content).to include('class GoldTransferredEvent < Servus::Event')
  end
end
