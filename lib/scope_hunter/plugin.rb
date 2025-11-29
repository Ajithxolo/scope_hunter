# frozen_string_literal: true

module ScopeHunter
  # RuboCop plugin class for gem integration
  class Plugin < RuboCop::Plugin
    def self.plugin_name
      "scope_hunter"
    end
  end
end
