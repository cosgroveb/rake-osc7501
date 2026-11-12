# frozen_string_literal: true
# rbs_inline: enabled

require 'bundler'
require 'open3'
require 'rubygems/installer'
require 'tmpdir'
require 'fileutils'

# Run packaged code with an isolated gem home and no checkout load paths.
class InstalledSmoke
  # @rbs @package: String
  # @rbs @rspec_package: String?
  # @rbs @rake: String
  # @rbs @entrypoint: String

  #: (String, String?) -> void
  def initialize(package, rspec_package)
    @package = File.expand_path(package)
    @rspec_package = File.expand_path(rspec_package) if rspec_package
  end

  #: () -> void
  def run
    Dir.mktmpdir('rake-osc7501-installed-') do |directory|
      dependencies = ['rake']
      dependencies += %w[rspec-core rspec-support] if @rspec_package
      dependencies.each do |name|
        installed = install(Gem.loaded_specs.fetch(name).cache_file, directory)
        @rake = File.join(installed.full_gem_path, installed.bindir, 'rake') if name == 'rake'
      end
      installed = install(@package, directory)
      @entrypoint = File.realpath(File.join(installed.full_gem_path, 'lib/rake/osc7501.rb'))
      check(directory, false, false)
      check(directory, true, false)
      if @rspec_package
        install(@rspec_package, directory)
        check(directory, false, true)
        check(directory, true, true)
      end
    end
    puts 'Installed Rake pass/fail verified' + (@rspec_package ? ', including retained RSpec children' : ' without RSpec')
  end

  private

  #: (String, String) -> Gem::Specification
  def install(package, directory)
    constructor = Gem::Installer.respond_to?(:at) ? :at : :new
    Gem::Installer.public_send(constructor, package, install_dir: directory, ignore_dependencies: true).install
  end

  #: (String, bool, bool) -> void
  def check(directory, failing, paired)
    source = paired ? "require 'rspec/core/rake_task'\n" : ''
    source += "require 'rake/osc7501'\n"
    source += "abort 'Wrong installed entrypoint' unless $LOADED_FEATURES.include?(#{@entrypoint.inspect})\n"
    if paired
      FileUtils.mkdir_p(File.join(directory, 'spec'))
      body = failing ? 'fail "expected failure"' : 'true'
      File.write(File.join(directory, 'spec/sample_spec.rb'), "RSpec.describe('installed') { it { #{body} } }")
      source += 'RSpec::Core::RakeTask.new(:default)'
    else
      source += "abort 'RSpec loaded' unless $LOADED_FEATURES.grep(%r{/rspec/}).empty?\n"
      unless @rspec_package
        source += "abort 'RSpec installed' if Gem::Specification.any? { |spec| spec.name.start_with?('rspec') }\n"
      end
      source += "task(:default) { puts 'ordinary output'; #{failing ? 'fail "expected failure"' : 'true'} }"
    end
    File.write(File.join(directory, 'Rakefile'), source)
    environment = { 'GEM_HOME' => directory, 'GEM_PATH' => directory, 'HOME' => directory,
                    'RUBYOPT' => nil, 'RUBYLIB' => nil, 'BUNDLE_GEMFILE' => nil, 'SPEC_OPTS' => nil,
                    'RAKE_OSC7501' => 'force', 'RSPEC_OSC7501' => 'force', 'RSPEC_OSC7501_ID' => nil }
    clean = Bundler.respond_to?(:with_unbundled_env) ? :with_unbundled_env : :with_clean_env
    output, error, status = Bundler.public_send(clean) do
      Open3.capture3(environment, Gem.ruby, @rake, chdir: directory)
    end
    expected = failing ? 'error' : 'done'
    raise "Wrong process outcome: #{output}\n#{error}" unless status.exitstatus == (failing ? 1 : 0)

    records = output.scan(/\e\]7501;([^\e]*)\e\\/).map do |(body)|
      body.split(':').map do |field|
        field.split('=', 2)
      end.to_h
    end
    raise 'Wrong parent outcome' unless records.last['app'] == 'rake' && records.last['state'] == expected
    raise 'Unexpected record cleanup' if records.any? { |record| record['state'] == 'clear' }

    ordinary = paired ? '1 example' : 'ordinary output'
    raise 'Ordinary output missing' unless output.include?(ordinary)
    return unless paired

    child = records.select { |record| record['app'] == 'rspec' }
    raise 'Missing child final' unless child.last && child.last['state'] == expected
    raise 'Wrong child identity' unless child.all? { |record| record['id'] == records.first['id'] + '/rspec-1' }
  end
end

InstalledSmoke.new(ARGV.fetch(0), ARGV[1]).run if $PROGRAM_NAME == __FILE__
