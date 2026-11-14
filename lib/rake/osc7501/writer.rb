# frozen_string_literal: true
# rbs_inline: enabled

module Rake
  module OSC7501
    class Writer # :nodoc: all
      # @rbs @output: IO | StringIO
      # @rbs @enabled: bool

      TITLE_BYTE_LIMIT = 512
      TITLE_PREFIX = 'rake' #: String

      #: (IO | StringIO output, mode: String) -> void
      def initialize(output, mode:)
        raise ArgumentError, 'RAKE_OSC7501 must be auto, off, or force' unless %w[auto off force].include?(mode)

        @output = output
        @enabled = mode == 'force' || (mode == 'auto' && automatic_output?)
      rescue IOError, SystemCallError
        @enabled = false
      end

      #: (state: String, msg: String, ?window_title: String?) -> void
      def emit(state:, msg:, window_title: nil)
        return unless @enabled

        # Compose only after sanitizing the name so binary input cannot mix encodings.
        name = window_title && sanitize(window_title, TITLE_BYTE_LIMIT)
        title = name && !name.empty? && sanitize(TITLE_PREFIX + ' › ' + name, TITLE_BYTE_LIMIT)
        @output.write("\e]2;#{title || TITLE_PREFIX}\e\\")
        fields = ['app=rake', 'title=UmFrZQ==', "state=#{state}", "msg=#{[sanitize(msg, 2048)].pack('m0')}"]
        @output.write("\e]7501;#{fields.join(':')}\e\\")
        @output.flush if @output.respond_to?(:flush)
      rescue IOError, SystemCallError
        @enabled = false
      end

      private

      #: () -> bool
      def automatic_output?
        ENV['TERM'] != 'dumb' && @output.respond_to?(:tty?) && @output.tty?
      end

      #: (String, Integer) -> String
      def sanitize(text, byte_limit)
        input = text.to_s.byteslice(0, sanitization_byte_limit(byte_limit)) #: String
        clean = input.encode('UTF-8', invalid: :replace, undef: :replace).gsub(/[\u0000-\u001F\u007F-\u009F]/, '')
        bytes = 0
        clean.each_char.take_while do |char|
          bytes += char.bytesize
          bytes <= byte_limit
        end.join
      end

      # Bound sanitization work with 50% headroom for stripped controls.
      #: (Integer) -> Integer
      def sanitization_byte_limit(output_byte_limit)
        output_byte_limit + output_byte_limit / 2
      end
    end
  end
end
