# frozen_string_literal: true
# rbs_inline: enabled

require 'rubygems/package_task'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
Gem::PackageTask.new(Gem::Specification.load('rake-osc7501.gemspec')) do |task|
  task.package_dir = 'pkg'
end

desc 'Generate and validate inline RBS and check annotation coverage'
task :types do
  ruby 'script/check_types.rb'
end

task default: [:spec, :types]
