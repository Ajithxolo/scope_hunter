# frozen_string_literal: true

require "scope_hunter/version" if File.exist?(File.join(__dir__, "scope_hunter/version.rb"))

require "scope_hunter/ast_utils"
require "scope_hunter/canonicalizer"
require "scope_hunter/scope_index"
require "scope_hunter/plugin"

# When rubocop loads, inject our default config
begin
  require "rubocop"
  require "rubocop/scope_hunter/inject"
rescue LoadError
  # rubocop not present (e.g., runtime only) — that's fine
end
