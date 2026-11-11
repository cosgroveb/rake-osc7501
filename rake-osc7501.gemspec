# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'lib/rake/osc7501/version'

Gem::Specification.new do |spec|
  spec.name = 'rake-osc7501'
  spec.version = Rake::OSC7501::VERSION
  spec.authors = ['Brian Cosgrove']
  spec.summary = 'Opt-in OSC 7501 terminal status for Rake tasks'
  spec.homepage = 'https://github.com/cosgroveb/rake-osc7501'
  spec.license = 'Apache-2.0'
  spec.required_ruby_version = '>= 2.1'
  spec.files = Dir['lib/**/*.rb'] + %w[README.md CHANGELOG.md LICENSE]
  spec.require_paths = ['lib']
  spec.add_runtime_dependency 'rake', '>= 12.3.3'
end
