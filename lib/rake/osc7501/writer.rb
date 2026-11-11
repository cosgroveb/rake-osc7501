# frozen_string_literal: true
# rbs_inline: enabled

module Rake
  module OSC7501
    class Writer # :nodoc: all
      # @rbs @output: IO | StringIO
      # @rbs @id: String
      # @rbs @enabled: bool
      #: (String?) -> bool
      def self.valid_id?(id)
        id.is_a?(String) && id.ascii_only? && id.bytesize <= 128 &&
          !!(id =~ /\A[A-Za-z0-9_.+-]{1,32}(?:\/[A-Za-z0-9_.+-]{1,32}){0,7}\z/)
      end

      #: (IO | StringIO output, mode: String, id: String) -> void
      def initialize(output, mode:, id:)
        raise ArgumentError, 'RAKE_OSC7501 must be auto, off, or force' unless %w[auto off force].include?(mode)

        @output = output
        @id = id
        @enabled = self.class.valid_id?(id) &&
                   (mode == 'force' || (mode == 'auto' && automatic_output?))

      rescue IOError, SystemCallError
        @enabled = false
      end

      #: (state: String, msg: String) -> void
      def emit(state:, msg:)
        return unless @enabled

        fields = ['app=rake', 'title=UmFrZQ==', "state=#{state}", "msg=#{encode(msg, 2048)}"]
        fields << "id=#{@id}" if @id
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
      def encode(text, byte_limit)
        input = text.to_s.byteslice(0, sanitization_byte_limit(byte_limit))
        clean = input.encode('UTF-8', invalid: :replace, undef: :replace).gsub(/[\u0000-\u001F\u007F-\u009F]/, '')
        bytes = 0
        bounded = clean.each_char.take_while do |char|
          bytes += char.bytesize
          bytes <= byte_limit
        end.join
        [bounded].pack('m0')
      end

      # Bound sanitization work with 50% headroom for stripped controls.
      #: (Integer) -> Integer
      def sanitization_byte_limit(output_byte_limit)
        output_byte_limit + output_byte_limit / 2
      end
    end
  end
end
