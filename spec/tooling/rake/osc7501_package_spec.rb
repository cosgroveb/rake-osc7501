# frozen_string_literal: true
# rbs_inline: enabled

require 'spec_helper'
require 'bundler'
require 'fileutils'
require 'open3'
require 'rubygems/package'
require 'rubygems/installer'
require 'tmpdir'

RSpec.describe Rake::OSC7501, :aggregate_failures do
  let(:root) { File.expand_path('../../..', __dir__) }
  let(:directory) { Dir.mktmpdir('rake-osc7501-package-') }
  let(:specification) { Gem::Specification.load(File.join(root, 'rake-osc7501.gemspec')) }
  let(:home) { File.join(directory, 'gems') }
  let(:package_path) { File.join(directory, 'pkg', "#{specification.full_name}.gem") }

  before do
    (specification.files + ['Rakefile', 'rake-osc7501.gemspec']).each do |path|
      destination = File.join(directory, path)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(File.join(root, path), destination)
    end
    output, error, status = Open3.capture3({ 'BUNDLE_GEMFILE' => File.join(root, 'Gemfile') },
                                           'bundle', 'exec', 'rake', 'package', chdir: directory)
    raise "#{output}\n#{error}" unless status.success?

    Gem::Installer.at(package_path, install_dir: home, ignore_dependencies: true).install
  end

  after { FileUtils.remove_entry(directory) }

  it 'packages only generated runtime signatures and keeps Rake as its sole dependency' do
    signatures = Dir[File.join(root, 'lib/**/*.rb')].map do |path|
      path.delete_prefix("#{root}/lib/").sub(/\.rb\z/, '.rbs').prepend('sig/')
    end
    expect(Gem::Package.new(package_path).spec.files.grep(/\.rbs\z/)).to match_array(signatures)
    expect(Gem::Package.new(package_path).spec.runtime_dependencies.map(&:name)).to eq(['rake'])
  end

  it 'lets consumers discover and validate installed signatures by gem name' do
    environment = { 'GEM_PATH' => ([home] + Gem.path).join(File::PATH_SEPARATOR) }
    output, error, status = Bundler.with_unbundled_env do
      Open3.capture3(environment, 'rbs', '-r', 'stringio', '-r', 'rake-osc7501', 'validate', chdir: directory)
    end
    expect(status.success?).to be(true), "#{output}\n#{error}"
  end
end
