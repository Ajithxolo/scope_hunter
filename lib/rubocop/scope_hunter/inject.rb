# frozen_string_literal: true

require_relative "cop/scope_hunter/use_existing_scope"

module RuboCop
  module ScopeHunter
    def self.inject!
      path = File.expand_path("../../config/default.yml", __FILE__)
      hash = ::RuboCop::ConfigLoader.send(:load_yaml_configuration, path)
      config = ::RuboCop::Config.new(hash, path)
      ::RuboCop::ConfigLoader.default_configuration = ::RuboCop::ConfigLoader
        .merge_with_default(config, ::RuboCop::ConfigLoader.default_configuration)
    end
  end
end

RuboCop::ScopeHunter.inject!
