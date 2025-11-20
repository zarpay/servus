# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in servus.gemspec
gemspec

gem 'active_model_serializers'
gem 'activesupport'
gem 'json-schema'
gem 'rake', '~> 13.0'

# Development and test dependencies
group :development, :test do
  gem 'activejob'
  gem 'railties'

  gem 'rspec', '~> 3.0'
  gem 'rspec-rails' # gives you `have_enqueued_job` matcher

  # Yard
  gem 'redcarpet', require: false
  gem 'webrick', require: false # Required for yard server
  gem 'yard', require: false
  gem 'yardstick', require: false

  # Rubocop
  gem 'rubocop', require: false
  gem 'rubocop-yard', require: false
end
