# frozen_string_literal: true
# rbs_inline: enabled

require 'spec_helper'
require_relative '../support/rake_suite'
require 'json'

RSpec.describe 'managed RSpec tasks' do
  before do
    skip 'run with Gemfile.integration or paired Gemfile.compat' unless Gem.loaded_specs.key?('rspec-osc7501')
  end

  let(:passing) { 'RSpec.describe("sample") { it("passes") {} }' }
  let(:setup) { "require 'rspec/core/rake_task'\nrequire 'rake/osc7501'\n" }

  it 'adds exactly one child while retaining ordinary progress' do
    output, error, status = RakeSuite.run(setup + 'RSpec::Core::RakeTask.new(:default)', [], {},
                                          'spec/sample_spec.rb' => passing)
    expect(status.success?).to eq(true), error
    expect(output).to include('1 example, 0 failures')
    records = frames(output)
    children = records.select { |r| r['app'] == 'rspec' }
    expect(children.map { |r| r['state'] }).to eq(%w[working done])
    expect(children.map { |r| r['id'] }.uniq).to eq([records.first['id'] + '/rspec-1'])
    expect(records.last['state']).to eq('done')
    expect(records.map { |r| r['state'] }).not_to include('clear')
  end

  ['--require rspec/osc7501 --format RSpec::OSC7501::Formatter --format progress', '--format documentation',
   '--format json --out result.out'].each do |options|
    it "preserves formatter selection #{options}" do
      output, error, status, files = RakeSuite.run(setup + 'RSpec::Core::RakeTask.new(:default)', [], {},
                                                   'spec/sample_spec.rb' => passing, '.rspec' => options)
      expect(status.success?).to eq(true), error
      expect(frames(output).count { |r| r['app'] == 'rspec' && r['state'] == 'done' }).to eq(1)
      expect(JSON.parse(files['result.out'])['summary']['failure_count']).to eq(0) if files['result.out']
    end
  end

  it 'preserves explicit OSC file destinations' do
    output, error, status, files = RakeSuite.run(setup + 'RSpec::Core::RakeTask.new(:default)', [], {},
                                                 'spec/sample_spec.rb' => passing,
                                                 '.rspec' => '--require rspec/osc7501 --format RSpec::OSC7501::Formatter --out child.out --format progress')
    expect(status.success?).to eq(true), error
    expect(frames(output).map { |r| r['app'] }.uniq).to eq(['rake'])
    expect(frames(files['child.out']).last['state']).to eq('done')
  end

  it 'supports existing tasks, re-enabling and unchanged parent options and environment' do
    source = <<-CODE
      require 'rspec/core/rake_task'
      suite = RSpec::Core::RakeTask.new(:spec)
      require 'rake/osc7501'
      before_env = ENV.to_h
      before_opts = suite.ruby_opts
      task :default do
        2.times { Rake::Task[:spec].reenable; Rake::Task[:spec].invoke }
        abort 'ENV changed' unless ENV.to_h == before_env
        abort 'options changed' unless suite.ruby_opts == before_opts
      end
    CODE
    output, error, status = RakeSuite.run(source, [], {}, 'spec/sample_spec.rb' => passing)
    expect(status.success?).to eq(true), error
    ids = frames(output).select { |r| r['app'] == 'rspec' && r['state'] == 'done' }.map { |r| r['id'] }
    expect(ids.uniq.size).to eq(2)
  end

  it 'assigns distinct child IDs to concurrent tasks' do
    source = setup + <<-CODE
      RSpec::Core::RakeTask.new(:one)
      RSpec::Core::RakeTask.new(:two)
      multitask :default => [:one, :two]
    CODE
    output, error, status = RakeSuite.run(source, [], {}, 'spec/sample_spec.rb' => passing)
    expect(status.success?).to eq(true), error
    ids = frames(output).select { |r| r['app'] == 'rspec' && r['state'] == 'done' }.map { |r| r['id'] }
    expect(ids.uniq.size).to eq(2)
  end

  it 'passes reporting controls through a clean child environment' do
    require 'rspec/core/rake_task'
    skip 'RSpec version lacks clean environments' unless RSpec::Core::RakeTask.method_defined?(:with_clean_environment=)
    source = setup + 'RSpec::Core::RakeTask.new(:default) { |t| t.with_clean_environment = true }'
    output, error, status = RakeSuite.run(source, [], {}, 'spec/sample_spec.rb' => passing)
    expect(status.success?).to eq(true), error
    expect(frames(output).select { |r| r['app'] == 'rspec' }.map { |r| r['state'] }).to eq(%w[working done])
  end

  it 'retains a successful child when later Rake work fails' do
    source = setup + "RSpec::Core::RakeTask.new(:spec)\ntask(:default => :spec) { raise 'later' }"
    output, _, status = RakeSuite.run(source, [], {}, 'spec/sample_spec.rb' => passing)
    expect(status.exitstatus).to eq(1)
    expect(frames(output).select { |r| r['app'] == 'rspec' }.last['state']).to eq('done')
    expect(frames(output).last['state']).to eq('error')
  end

  it 'retains a failing child when fail_on_error is false' do
    source = setup + 'RSpec::Core::RakeTask.new(:default) { |t| t.fail_on_error = false }'
    output, error, status = RakeSuite.run(source, [], {},
                                          'spec/sample_spec.rb' => 'RSpec.describe("bad") { it { fail "bad" } }')
    expect(status.success?).to eq(true), error
    expect(frames(output).select { |r| r['app'] == 'rspec' }.last['state']).to eq('error')
    expect(frames(output).last['state']).to eq('done')
  end

  { 'before callbacks' => ['exit! 7', nil],
    'SIGINT termination' => ["Signal.trap('INT', 'DEFAULT'); Process.kill('INT', Process.pid)", nil],
    'after successful summary' => ['at_exit { exit 7 }; RSpec.describe("ok") { it {} }',
                                   'done'] }.each do |label, fixture|
    it "preserves independent process failure #{label}" do
      source = setup + 'RSpec::Core::RakeTask.new(:default)'
      files = { 'spec/sample_spec.rb' => fixture.first }
      output, _, status = RakeSuite.run(source, [], {}, files)
      _, _, baseline = RakeSuite.run(source, [], { 'RAKE_OSC7501' => 'off' }, files)
      expect(status.exitstatus).to eq(baseline.exitstatus)
      expect(status.success?).to eq(false)
      records = frames(output)
      finals = records.select { |r| r['app'] == 'rspec' && r['state'] != 'working' }
      expect(finals.map { |r| r['state'] }).to eq(fixture.last ? [fixture.last] : [])
      expect(records.last['state']).to eq('error')
      expect(records.map { |r| r['state'] }).not_to include('clear')
    end
  end

  it 'leaves custom runners unchanged' do
    source = setup + "RSpec::Core::RakeTask.new(:default) { |t| t.rspec_path = 'runner.rb' }"
    runner = "abort 'managed custom runner' if ENV['RSPEC_OSC7501_ID']; puts 'CUSTOM'"
    output, error, status = RakeSuite.run(source, [], {}, 'runner.rb' => runner)
    expect(status.success?).to eq(true), error
    expect(output).to include('CUSTOM')
    expect(frames(output).map { |r| r['app'] }.uniq).to eq(['rake'])
  end

  it 'escapes an optional gem path containing spaces' do
    source = setup + <<-CODE
      require 'fileutils'
      gem = Gem.loaded_specs.fetch('rspec-osc7501')
      path = File.expand_path('reporter with spaces')
      FileUtils.mkdir_p(path)
      FileUtils.cp_r(File.join(gem.full_gem_path, 'lib'), path)
      Gem.loaded_specs['rspec-osc7501'] = Struct.new(:full_gem_path).new(path)
      RSpec::Core::RakeTask.new(:default)
    CODE
    output, error, status = RakeSuite.run(source, [], {}, 'spec/sample_spec.rb' => passing)
    expect(status.success?).to eq(true), error
    expect(frames(output).select { |r| r['app'] == 'rspec' }.last['state']).to eq('done')
  end

  it 'leaves an old optional gem without managed.rb usable' do
    source = setup + <<-CODE
      require 'fileutils'
      path = File.expand_path('old reporter')
      FileUtils.mkdir_p(path)
      Gem.loaded_specs['rspec-osc7501'] = Struct.new(:full_gem_path).new(path)
      RSpec::Core::RakeTask.new(:default)
    CODE
    output, error, status = RakeSuite.run(source, [], {}, 'spec/sample_spec.rb' => passing)
    expect(status.success?).to eq(true), error
    expect(output).to include('1 example, 0 failures')
    expect(frames(output).map { |r| r['app'] }.uniq).to eq(['rake'])
  end

  it 'keeps reverse require order on generic Rake reporting' do
    source = "require 'rake/osc7501'; require 'rspec/core/rake_task'; RSpec::Core::RakeTask.new(:default)"
    output, error, status = RakeSuite.run(source, [], {}, 'spec/sample_spec.rb' => passing)
    expect(status.success?).to eq(true), error
    expect(frames(output).map { |r| r['app'] }.uniq).to eq(['rake'])
  end

  %w[RAKE_OSC7501 RSPEC_OSC7501].each do |control|
    it "honors #{control}=off" do
      output, error, status = RakeSuite.run(setup + 'RSpec::Core::RakeTask.new(:default)', [], { control => 'off' },
                                            'spec/sample_spec.rb' => passing)
      expect(status.success?).to eq(true), error
      expect(frames(output).select { |r| r['app'] == 'rspec' }).to be_empty
    end
  end
end
