# frozen_string_literal: true
# rbs_inline: enabled

source 'https://rubygems.org'

gemspec

rspec_minor = ENV.fetch('RSPEC_MINOR', '3.13')
gem 'bundler-audit'
gem 'rake'
gem 'rbs', '4.2.0', require: false
gem 'rbs-inline', '0.14.0', require: false
gem 'rdoc'
gem 'rspec', ENV.fetch('RSPEC_VERSION', "~> #{rspec_minor}.0")
gem 'rspec-core', ENV.fetch('RSPEC_CORE_VERSION', "~> #{rspec_minor}.0")
# Gemfile.integration substitutes a local checkout.
gem 'rspec-osc7501', '>= 0.1.4' unless ENV['RSPEC_OSC7501_PATH']
gem 'rubocop', '~> 1.92'
gem 'rubocop-rspec', '~> 3.10'
gem 'steep', '2.1.0', require: false
