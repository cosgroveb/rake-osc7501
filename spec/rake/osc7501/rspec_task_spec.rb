# frozen_string_literal: true
# rbs_inline: enabled

require 'spec_helper'
require 'rake/osc7501/rspec_task'
require 'tmpdir'
require 'rbconfig'

RSpec.describe Rake::OSC7501::RSpecTask do
  it 'merges child context without changing spawn options, input hashes or process status' do
    launcher = Object.new.extend(described_class)
    launcher.instance_variable_set(:@osc7501_context, ['rake-1-a/rspec-1', '/unused'])
    environment = { 'KEEP' => 'yes', 'RSPEC_OSC7501' => 'off' }
    Dir.mktmpdir('spawn-context') do |directory|
      file = File.join(directory, 'env')
      source = "File.write(ARGV[0], [ENV['KEEP'], ENV['RSPEC_OSC7501'], ENV['RSPEC_OSC7501_ID'], ENV.key?('HOME')].join('|')); exit 7"
      result = launcher.send(:system, environment, RbConfig.ruby, '-e', source, file, unsetenv_others: true)
      expect(result).to eq(false)
      expect($?.exitstatus).to eq(7)
      expect(File.read(file)).to eq('yes|off|rake-1-a/rspec-1|false')
      expect(environment).to eq('KEEP' => 'yes', 'RSPEC_OSC7501' => 'off')
    end
  end
end
