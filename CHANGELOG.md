## [Unreleased]

## [0.1.3] - 2026-03-27

### Added
- Cross-file scope detection: scopes defined in `app/models/` are indexed and matched
  against queries anywhere in the codebase (controllers, services, jobs, etc.)
- `where.not()` support: queries using `where.not(...)` are matched against scopes
  that use the same pattern
- `IgnoreModels` configuration option to exclude specific models from detection and indexing
- `ModelPaths` configuration option to control which files are scanned for scope definitions
- Parameterized scope matching: scopes with lambda parameters (e.g. `->(role) { where(role: role) }`)
  are matched against queries with literal values using the same key structure
- Dynamic value guard: queries with runtime values (`method calls`, `variables`) are never flagged

### Fixed
- `normalize_hash` raised `NoMethodError` when a scope lambda used a dynamic value as the
  entire where argument (e.g. `where(:__dynamic__)`)

### Changed
- Test suite expanded from 3 to 110+ examples with branch coverage tracking (94.5% line, 93.46% branch)

## [0.1.2] - 2025-11-01

### Changed
- Bumped version

## [0.1.1] - 2025-10-20

### Added
- LintRoller plugin integration for enhanced linting compatibility
- Default lint roller plugin metadata in gemspec
- YAML configuration files

## [0.1.0] - 2025-10-14

### Added
- Initial release
- `ScopeHunter/UseExistingScope` cop detects ActiveRecord queries matching named scopes
- Autocorrect support: replaces matched query with `Model.scope_name`
- Trailing method chain preservation during autocorrect
- Signature normalization: hash key order, `rewhere` treated as `where`
