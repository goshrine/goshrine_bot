# Available options:
#
# rake test - Runs all test cases.
# rake package - Runs test cases and builds packages for distribution.
# rake rdoc - Builds API documentation in doc dir.

require 'rake'
require 'rspec/core/rake_task'
require 'rubygems/package_task'

task :default => :spec

RSpec::Core::RakeTask.new do |rspec|
  #rspec.ruby_opts="-w"
end

load(File.join(File.dirname(__FILE__), "goshrine_bot.gemspec"))

Gem::PackageTask.new(SPEC) do |package|
  # do nothing: I just need a gem but this block is required
end

