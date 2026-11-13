# frozen_string_literal: true
# rbs_inline: enabled

require 'spec_helper'
require 'fileutils'
require 'open3'
require 'tmpdir'

RSpec.describe Rake::OSC7501, :aggregate_failures do
  let(:root) { File.expand_path('../../..', __dir__) }
  let(:directory) { Dir.mktmpdir('rake-osc7501-types-') }

  before do
    FileUtils.cp(File.join(root, 'Steepfile'), directory)
    FileUtils.cp_r(File.join(root, 'sig'), directory)
    %w[Gemfile Rakefile rake-osc7501.gemspec].each do |file|
      File.write(File.join(directory, file), "# rbs_inline: enabled\n")
    end
  end

  after { FileUtils.remove_entry(directory) }

  #: (String, String) -> Integer
  def write_probe(path, expression)
    source = File.join(directory, path)
    FileUtils.mkdir_p(File.dirname(source))
    File.write(source, <<~RUBY)
      # rbs_inline: enabled
      class TypeCheckFixture
        #: () -> Integer
        def count
          #{expression}
        end
      end
    RUBY
  end

  #: (String, String) -> [String, String, Process::Status]
  def check_implementation(path, expression)
    write_probe(path, expression)
    Open3.capture3({ 'BUNDLE_GEMFILE' => File.join(root, 'Gemfile') },
                   'bundle', 'exec', 'ruby', File.join(root, 'script/check_types.rb'), chdir: directory)
  end

  it 'accepts an implementation matching its inline signature' do
    output, error, status = check_implementation('lib/probe.rb', '3')
    expect(status.success?).to be(true), "#{output}\n#{error}"
  end

  %w[lib script].each do |directory|
    it "rejects a return type mismatch in #{directory}" do
      output, error, status = check_implementation("#{directory}/probe.rb", '"three"')
      expect(status.success?).to be(false), "#{output}\n#{error}"
      expect(output).to include("#{directory}/probe.rb", 'Ruby::MethodBodyTypeMismatch')
    end
  end
end
