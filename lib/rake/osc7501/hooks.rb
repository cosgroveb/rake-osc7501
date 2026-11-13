# frozen_string_literal: true
# rbs_inline: enabled

module Rake
  # @rbs!
  #   class Application
  #     include OSC7501::ApplicationHook
  #   end

  module OSC7501
    # @rbs module-self ::Rake::_Application
    module ApplicationHook
      attr_reader :osc7501_run #: Run?

      #: () -> Object
      def top_level
        return super if options.show_tasks || options.show_prereqs || options.dryrun

        previous = @osc7501_run
        begin
          run = Run.new($stdout, mode: ENV.fetch('RAKE_OSC7501', 'auto'))
          @osc7501_run = run
          run.during_run { super }
        ensure
          @osc7501_run = previous
        end
      end
    end

    # @rbs module-self ::Rake::Task
    module TaskHook
      #: (?Object args) ?{ (*Object) -> Object } -> Object
      def execute(args = nil, &block)
        run = application.osc7501_run if application.respond_to?(:osc7501_run)
        return super unless run

        run.during_task(self) { super(args, &block) }
      end
    end
  end
end
