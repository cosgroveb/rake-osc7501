# frozen_string_literal: true
# rbs_inline: enabled

require 'ripper'
require 'rbs'
require 'fileutils'
require 'rbconfig'

files = Dir['{lib,spec,script}/**/*.rb'] + Dir['Gemfile*'].reject { |f| f.end_with?('.lock') } + %w[Rakefile rake-osc7501.gemspec]
methods = 0
files.each do |path|
  source = File.read(path)
  abort "Missing inline RBS opt-in: #{path}" unless source.include?('# rbs_inline: enabled')
  lines = source.lines
  Ripper.lex(source).each do |position, event, token, _state|
    next unless event == :on_kw && token == 'def'

    index = position.first - 2
    comments = []
    while index >= 0 && lines[index].lstrip.start_with?('#')
      comments.unshift(lines[index])
      index -= 1
    end
    signature = comments.join[/^\s*#:\s*(.+)$/, 1]
    abort "Missing method annotation: #{path}:#{position.first}" unless signature
    abort "Untyped method annotation: #{path}:#{position.first}" if signature.match?(/\buntyped\b/)
    RBS::Parser.parse_method_type(signature)
    methods += 1
  end
end

FileUtils.rm_rf('tmp/signatures')
files.each_with_index do |path, index|
  # Separate outputs avoid Gemfile/Gemfile.compat basename collisions.
  success = system('rbs-inline', '--base=.', "--output=tmp/signatures/#{index}", path)
  abort "Signature generation failed: #{path}" unless success
end
abort 'Signature validation failed' unless system('rbs', '-I', 'tmp/signatures', '-r', 'stringio', 'validate')
puts "Validated inline RBS: #{files.size} files, #{methods} methods"
