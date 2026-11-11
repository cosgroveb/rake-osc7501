# frozen_string_literal: true
# rbs_inline: enabled

require 'spec_helper'
require_relative '../support/rake_suite'

RSpec.describe 'Rake reporting' do
  it 'reports plain prerequisites, arguments, nested invokes and re-enabled actions without loading RSpec' do
    source = <<-CODE
      existing = $LOADED_FEATURES.grep(%r{/rspec/})
      require 'rake/osc7501'
      task(:shared) { puts 'SHARED' }
      task(:nested) { puts 'NESTED' }
      task :work, [:name] => :shared do |_, args|
        puts args[:name]
        Rake::Task[:nested].invoke
        Rake::Task[:shared].reenable
        Rake::Task[:shared].invoke
        abort 'RSpec loaded' unless ($LOADED_FEATURES.grep(%r{/rspec/}) - existing).empty?
      end
      task :default => [:shared, :work]
    CODE
    output, error, status = RakeSuite.run(source, ['work[Brian]'])
    expect(status.success?).to eq(true), error
    expect(output.scan('SHARED').size).to eq(2)
    expect(output).to include('NESTED', 'Brian')
    expect(frames(output).map { |r| r['msg'] }).to include('shared', '2 active tasks', 'work')
    expect(frames(output).last['state']).to eq('done')
  end

  it 'skips up-to-date file tasks and deduplicates shared prerequisites while executing rules' do
    source = <<-CODE
      require 'rake/osc7501'
      file('exists') { abort 'not needed' }
      task(:shared) { puts 'SHARED' }
      rule('.out' => '.in') { |t| File.write(t.name, 'built') }
      task :one => :shared
      task :two => :shared
      task :default => [:one, :two, 'exists', 'sample.out']
    CODE
    output, error, status = RakeSuite.run(source, [], {}, 'exists' => '', 'sample.in' => '')
    expect(status.success?).to eq(true), error
    expect(output.scan('SHARED').size).to eq(1)
    expect(frames(output).map { |r| r['msg'] }).not_to include('exists')
    expect(frames(output).map { |r| r['msg'] }).to include('sample.out')
  end

  ['-T', '-P', '-n', '-D', '-W', '-V'].each do |flag|
    it "does not report inspection #{flag}" do
      output, error, status = RakeSuite.run("require 'rake/osc7501'; desc 'work'; task(:default) {}", [flag])
      expect(status.success?).to eq(true), error
      expect(frames(output)).to be_empty
    end
  end

  { 'raise "bad"' => ['error', 1], 'exit 7' => ['error', 7], 'exit 0' => ['idle', 0], 'raise Interrupt' => ['idle', 1] }.each do |body, result|
    it "preserves task outcome #{body}" do
      source = "require 'rake/osc7501'; task(:default) { #{body} }"
      output, _, status = RakeSuite.run(source)
      _, _, baseline = RakeSuite.run(source, [], 'RAKE_OSC7501' => 'off')
      expect(status.exitstatus).to eq(baseline.exitstatus)
      expect(status.exitstatus).to eq(result.last)
      expect(frames(output).last['state']).to eq(result.first)
    end
  end

  it 'reports overlapping multitask actions' do
    source = <<-CODE
      require 'rake/osc7501'
      task(:one) { sleep 0.1 }
      task(:two) { sleep 0.1 }
      multitask :default => [:one, :two]
    CODE
    output, error, status = RakeSuite.run(source)
    expect(status.success?).to eq(true), error
    expect(frames(output).map { |r| r['msg'] }).to include('2 active tasks')
    expect(frames(output).last['state']).to eq('done')
  end

  it 'reports a real terminal in auto mode and silences TERM=dumb' do
    source = "require 'rake/osc7501'; task(:default) { puts 'OK' }"
    output, error, status = RakeSuite.run(source, [], { 'RAKE_OSC7501' => 'auto', 'TERM' => 'xterm' }, {}, true)
    expect(status.success?).to eq(true), error
    expect(frames(output).last['state']).to eq('done')
    output, error, status = RakeSuite.run(source, [], { 'RAKE_OSC7501' => 'auto', 'TERM' => 'dumb' }, {}, true)
    expect(status.success?).to eq(true), error
    expect(frames(output)).to be_empty
  end

  %w[auto off].each do |mode|
    it "silences non-TTY #{mode} output" do
      output, error, status = RakeSuite.run("require 'rake/osc7501'; task(:default) { puts 'OK' }", [], 'RAKE_OSC7501' => mode)
      expect(status.success?).to eq(true), error
      expect(output).to eq("OK\n")
    end
  end
end
