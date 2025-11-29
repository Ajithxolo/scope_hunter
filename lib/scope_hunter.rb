# frozen_string_literal: true

require "scope_hunter/version" if File.exist?(File.join(__dir__, "scope_hunter/version.rb"))

require "scope_hunter/ast_utils"
require "scope_hunter/canonicalizer"
require "scope_hunter/scope_index"

# When rubocop loads, inject our default config
begin
  require "rubocop"
  # Load the cop BEFORE inject to ensure it's registered
  require "rubocop/cop/scope_hunter/use_existing_scope"
  require "rubocop/scope_hunter/inject"
rescue LoadError
  # rubocop not present (e.g., runtime only) — that's fine
end
