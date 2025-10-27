# frozen_string_literal: true

require "lint_roller"

module ScopeHunter
  class Plugin < LintRoller::Plugin
    def name = "scope_hunter"
    def version = ::ScopeHunter::VERSION

    # Tell Standard/RuboCop how to load our cops + config
    def rules
      LintRoller::Rules.new(
        rubocop: {
          # require our gem so the injector runs and cops are available
          require: ["scope_hunter"],
          # point to the default config that enables the cop
          config: File.expand_path("../../config/default.yml", __FILE__)
        }
      )
    end
  end
end
