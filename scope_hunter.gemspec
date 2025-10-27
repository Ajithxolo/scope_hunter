# frozen_string_literal: true

require_relative "lib/scope_hunter/version"

Gem::Specification.new do |spec|
  spec.name = "scope_hunter"
  spec.version = ScopeHunter::VERSION
  spec.authors = ["Ajith kumar"]
  spec.email = ["ajithbuddy.kumar@gmail.com"]

  spec.summary = "RuboCop extension that suggests replacing ActiveRecord query chains with existing named scopes (with autocorrect)."
  spec.description = "Scope Hunter is a RuboCop extension that detects ActiveRecord query chains that duplicate existing named scopes and suggests using those scopes instead. It indexes model scopes, canonicalizes relation chains, and flags matches with an autocorrect that replaces the initial query with Model.scope while preserving any trailing methods. This keeps query logic DRY, improves readability, and helps teams discover and reuse well-named scopes."
  spec.homepage = "https://github.com/ajithbuddy/scope_hunter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ajithbuddy/scope_hunter"
  spec.metadata["changelog_uri"] = "https://github.com/ajithbuddy/scope_hunter/blob/main/CHANGELOG.md"
  spec.metadata["default_lint_roller_plugin"] = "ScopeHunter::Plugin"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.files += Dir["config/*.yml"]


  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "rubocop", ">= 1.60"
  spec.add_dependency "parser", "~> 3.3"
  spec.add_dependency "rubocop-ast", "~> 1.32"

  spec.add_development_dependency "standard", ">= 1.40"


  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
