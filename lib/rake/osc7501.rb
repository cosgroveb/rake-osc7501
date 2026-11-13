# frozen_string_literal: true
# rbs_inline: enabled

require 'rake'
require_relative 'osc7501/version'
require_relative 'osc7501/writer'
require_relative 'osc7501/run'
require_relative 'osc7501/hooks'

module Rake
  module OSC7501
    #: (?Object application) -> void
    def self.install!(application = Rake.application)
      application.extend(ApplicationHook) unless application.is_a?(ApplicationHook)
      Rake::Task.prepend(TaskHook) unless Rake::Task.ancestors.include?(TaskHook)
      install_rspec!
    end

    #: () -> void
    def self.install_rspec!
      return unless defined?(RSpec::Core::RakeTask)

      require_relative 'osc7501/rspec_task'
      RSpec::Core::RakeTask.prepend(RSpecTask) unless RSpec::Core::RakeTask.ancestors.include?(RSpecTask)
    end
  end
end

Rake::OSC7501.install!
