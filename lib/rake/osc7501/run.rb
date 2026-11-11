# frozen_string_literal: true
# rbs_inline: enabled

require 'securerandom'
require 'thread'

module Rake
  module OSC7501
    # @rbs!
    #   interface _TaskName
    #     def name: () -> String
    #   end

    class Run
      # @rbs @active: Array[_TaskName]
      # @rbs @counter: Integer
      # @rbs @mutex: Mutex
      # @rbs @id: String
      # @rbs @writer: Writer
      # @rbs @mode: String
      # @rbs @finished: bool

      #: (IO | StringIO output, mode: String) -> void
      def initialize(output, mode:)
        @mode = mode
        @id = "rake-#{Process.pid}-#{SecureRandom.hex(6)}"
        @writer = Writer.new(output, mode: mode, id: @id)
        @finished = false
        @active = []
        @counter = 0
        @mutex = Mutex.new
      end

      #: [T] () { () -> T } -> T
      def during_run
        @writer.emit(state: 'working', msg: 'Running tasks')
        result = yield
        finish('done', 'Completed')
        result
      rescue Exception => e # Preserve Rake's handling of Interrupt and SystemExit.
        stopped = e.is_a?(Interrupt) || (e.is_a?(SystemExit) && e.success?)
        finish(stopped ? 'idle' : 'error', stopped ? 'Stopped' : 'Failed')
        raise
      end

      #: [T] (_TaskName) { () -> T } -> T
      def during_task(task)
        @mutex.synchronize do
          @active << task
          report_active
        end
        begin
          yield
        ensure
          @mutex.synchronize do
            @active.delete_at(@active.rindex(task))
            report_active
          end
        end
      end

      #: () -> String
      def next_child_id
        @mutex.synchronize do
          @counter += 1
          "#{@id}/rspec-#{@counter}"
        end
      end

      #: () -> bool
      def managed_children?
        @mode != 'off'
      end

      private

      #: (String, String) -> void
      def finish(state, message)
        @mutex.synchronize do
          @finished = true
          @writer.emit(state: state, msg: message)
        end
      end

      #: () -> void
      def report_active
        return if @finished

        message = if @active.empty?
                    'Running tasks'
                  elsif @active.length == 1
                    @active.first.name
                  else
                    "#{@active.length} active tasks"
                  end
        @writer.emit(state: 'working', msg: message)
      end
    end
  end
end
