# frozen_string_literal: true
# rbs_inline: enabled

require 'stringio'
require 'rake/osc7501'

module FrameHelpers
  #: (String) -> Array[Hash[String, String]]
  def frames(output)
    output.scan(/\e\]7501;([^\e]*)\e\\/).map do |(body)|
      body.split(':').map do |field|
        key, value = field.split('=', 2)
        [key, %w[title msg].include?(key) ? value.unpack('m0').first.force_encoding('UTF-8') : value]
      end.to_h
    end
  end
end

RSpec.configure do |config|
  config.include FrameHelpers
  config.order = :random
  Kernel.srand config.seed
end
