# frozen_string_literal: true

require 'fileutils'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

# Constants
GEM_NAME   = 'servus'
BUILDS_DIR = 'builds'

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

RuboCop::RakeTask.new

# Build gem
task :build do
  FileUtils.mkdir_p(BUILDS_DIR)

  # Build gem in current directory
  sh "gem build #{GEM_NAME}.gemspec"

  # Move to builds directory
  gem_file = Dir["#{GEM_NAME}-*.gem"].first
  if gem_file
    FileUtils.mv(gem_file, BUILDS_DIR)
    puts "Moved #{gem_file} to #{BUILDS_DIR}/"
  end
end

# Install gem locally
task install: :build do
  gem_file = Dir["#{BUILDS_DIR}/#{GEM_NAME}-*.gem"].max_by { |f| File.mtime(f) }
  sh "gem install #{gem_file}"
end

# Publish gem to RubyGems.org
task publish: :build do
  gem_file = Dir["#{BUILDS_DIR}/#{GEM_NAME}-*.gem"].max_by { |f| File.mtime(f) }
  puts "Publishing #{gem_file} to RubyGems.org..."
  sh "gem push #{gem_file}"
end

task default: %i[spec rubocop]
