# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in servus.gemspec
gemspec

gem 'json-schema'
gem 'activesupport'
gem 'active_model_serializers'
gem 'rake', '~> 13.0'
gem 'rspec', '~> 3.0'

# Test only
group :test do
  gem 'activejob'
  gem 'railties'
  gem 'rspec-rails' # gives you `have_enqueued_job` matcher
end
