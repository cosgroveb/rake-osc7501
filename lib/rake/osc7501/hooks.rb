# frozen_string_literal: true
# rbs_inline: enabled

module Rake
  # @rbs!
  #   class Application
  #     include OSC7501::ApplicationHook
  #   end

  module OSC7501
    # @rbs!
    #   interface _Application
    #     def options: () -> _Options
    #     def top_level: () -> Object
    #   end
    #   interface _Options
    #     def show_tasks: () -> (:tasks | :describe | :lines)?
    #     def show_prereqs: () -> bool
    #     def dryrun: () -> bool
    #   end
    #   interface _Task
    #     def name: () -> String
    #     def application: () -> ::Rake::Application
    #     def execute: (?Object) ?{ (*Object) -> Object } -> Object
    #   end

    # @rbs module-self _Application
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

    # @rbs module-self _Task
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
