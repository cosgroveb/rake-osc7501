# frozen_string_literal: true
# rbs_inline: enabled

require 'rubygems/package_task'
require 'rdoc/task' unless ENV.fetch('BUNDLE_GEMFILE', '').end_with?('Gemfile.compat')
require 'rspec/core/rake_task'
require_relative 'lib/rake/osc7501'

RSpec::Core::RakeTask.new(:spec)
specification = Gem::Specification.load('rake-osc7501.gemspec')
Gem::PackageTask.new(specification) do |task|
  task.package_dir = 'pkg'
end

task :package_signatures do
  directory = "pkg/#{specification.full_name}"
  FileUtils.rm_rf("#{directory}/sig")
  sh 'rbs-inline', '--base=lib', "--output=#{directory}/sig", 'lib'
  specification.files += Dir["#{directory}/sig/**/*.rbs"].map { |path| path.sub("#{directory}/", '') }
end
Rake::Task["pkg/#{specification.full_name}.gem"].enhance([:package_signatures])

unless ENV.fetch('BUNDLE_GEMFILE', '').end_with?('Gemfile.compat')
  RDoc::Task.new do |task|
    task.main = 'README.md'
    task.rdoc_files.include('README.md', 'LICENSE', 'CHANGELOG.md', 'CONTRIBUTING.md', 'lib/**/*.rb', 'doc/**/*.rdoc')
    task.rdoc_files.include('CODE_OF_CONDUCT.md', 'SECURITY.md', 'ACCESSIBILITY.md')
    task.rdoc_dir = 'tmp/rdoc'
  end
end

desc 'Check release/build style and runtime Ruby correctness'
task :lint do
  sh 'rubocop', 'script/release.rb', 'spec/release_spec.rb', 'spec/tooling', 'Gemfile', 'Gemfile.compat',
     'Gemfile.integration', 'Rakefile', 'Steepfile', 'rake-osc7501.gemspec'
  sh 'rubocop', '--only', 'Lint', 'lib', 'spec/rake', 'spec/support', 'spec/spec_helper.rb',
     'script/smoke.rb', 'script/check_types.rb'
end

desc 'Check resolved dependencies for known vulnerabilities'
task :audit do
  sh 'bundle-audit', 'check', '--update'
end

desc 'Check GitHub Actions workflows'
task :workflows do
  sh 'actionlint'
end

desc 'Run lint, dependency and workflow checks'
task quality: %i[lint audit workflows types]

desc 'Run passing and failing suites against the installed gem'
task smoke: :package do
  specification = Gem::Specification.load('rake-osc7501.gemspec')
  ruby 'script/smoke.rb', "pkg/#{specification.full_name}.gem"
end

task default: %i[quality spec smoke rdoc]

desc 'Check runtime and tooling implementations against inline RBS'
task :types do
  ruby 'script/check_types.rb'
end
