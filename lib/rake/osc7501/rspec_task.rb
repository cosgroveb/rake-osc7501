# frozen_string_literal: true
# rbs_inline: enabled

require 'shellwords'

module Rake
  module OSC7501
    # @rbs!
    #   interface _RSpecRakeTask
    #     def run_task: (bool) -> Object
    #     def ruby_opts: () -> (String | Array[String] | nil)
    #     def rspec_path: () -> String
    #     def system: (*String | Hash[String, String?] | Hash[Symbol, bool]) -> bool?
    #   end

    # Wrap only the standard RSpec task's launch; keep its status handling intact.
    # @rbs module-self _RSpecRakeTask
    module RSpecTask
      # @rbs @osc7501_context: [String, String]?

      #: (bool) -> Object
      def run_task(verbose)
        previous = @osc7501_context
        begin
          run = Rake.application.osc7501_run if Rake.application.respond_to?(:osc7501_run)
          path = managed_path if run && run.managed_children?
          @osc7501_context = path && run ? [run.next_child_id, path] : nil
          super
        ensure
          @osc7501_context = previous
        end
      end

      #: () -> (String | Array[String] | nil)
      def ruby_opts
        options = super
        context = @osc7501_context
        return options unless context

        options = [options] if options.is_a?(String)
        (options || []) + ["-r#{Shellwords.escape(context.last)}"]
      end

      private

      #: () -> String?
      def managed_path
        return unless rspec_path == RSpec::Core::RakeTask::DEFAULT_RSPEC_PATH

        specification = Gem.loaded_specs['rspec-osc7501'] || Gem::Specification.find_all_by_name('rspec-osc7501').first
        return unless specification

        path = File.join(specification.full_gem_path, 'lib/rspec/osc7501/managed.rb')
        path if File.file?(path)
      end

      #: (*String | Hash[String, String?] | Hash[Symbol, bool]) -> bool?
      def system(*arguments)
        context = @osc7501_context
        return super unless context

        # @type var environment: Hash[String, String?]
        first = arguments.first
        if first.is_a?(Hash)
          arguments.shift
          environment = first.dup
        else
          environment = {}
        end
        environment['RSPEC_OSC7501_ID'] = context.first
        %w[RSPEC_OSC7501 RSPEC_OSC7501_TITLE TERM].each do |key|
          environment[key] = ENV[key] if ENV.key?(key) && !environment.key?(key)
        end
        super(environment, *arguments)
      end
    end
  end
end
