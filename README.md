# Scope Hunter

[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%203.2.0-red.svg)](https://www.ruby-lang.org/)
[![RuboCop](https://img.shields.io/badge/rubocop-%3E%3D%201.60-blue.svg)](https://rubocop.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE.txt)

> A RuboCop extension that catches duplicate ActiveRecord queries and replaces them with the named scope you already wrote.

---

## The Problem

Rails lets you define reusable query logic as named scopes:

```ruby
class User < ApplicationRecord
  scope :active, -> { where(status: :active) }
end
```

But over time, the same query gets copy-pasted elsewhere without anyone realising the scope already exists:

```ruby
# In a controller
User.where(status: :active)          # duplicates User.active

# In a service object
User.where(status: :active).order(:name)  # also duplicates it
```

Scope Hunter finds these duplicates automatically and fixes them with `rubocop -A`.

---

## Quick Start

**1. Add to your Gemfile:**

```ruby
gem 'scope_hunter'
```

**2. Add to `.rubocop.yml`:**

```yaml
require:
  - scope_hunter

ScopeHunter/UseExistingScope:
  Enabled: true
```

**3. Run RuboCop:**

```bash
bundle exec rubocop
```

That's it. Scope Hunter will scan your `app/models/` directory and flag any query that matches a named scope.

---

## What It Looks Like

Given this model:

```ruby
class User < ApplicationRecord
  scope :active,    -> { where(status: :active) }
  scope :with_posts, -> { joins(:posts) }
  scope :recent,    -> { order(created_at: :desc) }
end
```

Scope Hunter flags these:

```
app/controllers/users_controller.rb:5:5: C: ScopeHunter/UseExistingScope:
  Query matches `User.active`. Use the scope instead.
  User.where(status: :active)
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^

app/services/report.rb:12:5: C: ScopeHunter/UseExistingScope:
  Query matches `User.with_posts`. Use the scope instead.
  User.joins(:posts)
  ^^^^^^^^^^^^^^^^^^
```

Running `rubocop -A` autocorrects them:

```ruby
# Before
User.where(status: :active).order(:name).limit(10)

# After — the matched part is replaced; the rest is kept
User.active.order(:name).limit(10)
```

---

## Features

### Scope types detected

| Scope pattern | Example |
|---|---|
| `where` conditions | `scope :active, -> { where(status: :active) }` |
| `where.not` conditions | `scope :inactive, -> { where.not(status: :active) }` |
| `joins` | `scope :with_posts, -> { joins(:posts) }` |
| `order` | `scope :recent, -> { order(created_at: :desc) }` |
| Combined conditions | `scope :admin, -> { where(role: :admin).order(:name) }` |

### Smart matching

- **Hash key order doesn't matter** — `where(a: 1, b: 2)` matches `where(b: 2, a: 1)`
- **Parameterized scopes are matched by shape** — `scope :by_role, ->(r) { where(role: r) }` matches any `where(role: <value>)`
- **Trailing methods are preserved** — `.order()`, `.limit()`, and anything after the matched query are kept intact
- **Cross-file detection** — scopes defined in `app/models/` are detected even when the duplicate query is in a controller, service, or job
- **Dynamic values are ignored** — `User.where(status: current_user.status)` is never flagged because the runtime value is unknown

### Autocorrect

The cop ships with conservative autocorrect. Running `rubocop -A` will replace the flagged query with the scope name, preserving any chained methods that come after.

---

## Configuration

Add any of these to your `.rubocop.yml` under `ScopeHunter/UseExistingScope`:

```yaml
ScopeHunter/UseExistingScope:
  Enabled: true

  # Glob patterns for model files to scan for scope definitions.
  # Defaults to app/models/**/*.rb
  ModelPaths:
    - "app/models/**/*.rb"
    - "app/domain/**/*.rb"   # add extra paths as needed

  # Models to skip entirely — useful for legacy or auto-generated models
  # where scope reuse isn't practical.
  IgnoreModels:
    - LegacyReport
    - AdminAuditLog
```

### `ModelPaths`

Controls which files are scanned for scope definitions. By default, Scope Hunter reads everything under `app/models/`. If your project keeps models elsewhere, add those paths here.

### `IgnoreModels`

A list of model class names to exclude from both detection and indexing. Queries on these models are never flagged, and scopes inside them are never indexed.

---

## Detailed Examples

### `where.not`

```ruby
scope :inactive, -> { where.not(status: :active) }

# Flagged
User.where.not(status: :active)

# Autocorrected to
User.inactive
```

### Parameterized scope

The scope uses a lambda parameter — Scope Hunter matches by the key name, not the value.

```ruby
scope :by_role, ->(role) { where(role: role) }

# Flagged — value :admin doesn't matter, the key `role:` matches
User.where(role: :admin)

# Autocorrected to
User.by_role
```

### Dynamic values are safe

```ruby
scope :active, -> { where(status: :active) }

# NOT flagged — runtime value is unknown, could be anything
User.where(status: current_status)
User.where(status: @status)
User.where(status: params[:status])
```

### Cross-file detection

Scopes in your models are indexed once per run. You can write the query anywhere in your app:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  scope :active, -> { where(status: :active) }
end

# app/controllers/users_controller.rb
class UsersController < ApplicationController
  def index
    # Flagged — Scope Hunter found the matching scope in user.rb
    @users = User.where(status: :active)
  end
end
```

### Ignoring a model

```yaml
# .rubocop.yml
ScopeHunter/UseExistingScope:
  IgnoreModels:
    - LegacyReport
```

```ruby
# Not flagged — LegacyReport is in the ignore list
LegacyReport.where(status: :active)
```

---

## Running the cop

```bash
# Report all offenses
bundle exec rubocop

# Scan only your models directory
bundle exec rubocop app/models/

# Run only this cop
bundle exec rubocop --only ScopeHunter/UseExistingScope

# Autocorrect all offenses
bundle exec rubocop -A

# Autocorrect only this cop
bundle exec rubocop --only ScopeHunter/UseExistingScope -A
```

---

## How It Works (for the curious)

1. **Index** — Before checking any file, Scope Hunter reads every file matched by `ModelPaths` and builds an in-memory index of all named scopes, keyed by a normalized signature.
2. **Normalize** — Each scope's query chain is reduced to a canonical form: `M=User|W={status:?}|J=[]|O=[]`. Values are replaced with `?` so the shape is matched, not the literal value.
3. **Detect** — For every ActiveRecord query found in the file being checked, the same normalization is applied and the result is looked up in the index.
4. **Flag** — If a match is found, an offense is reported. Queries with dynamic values are skipped before this step.
5. **Autocorrect** — The matched portion of the query is replaced with `Model.scope_name`; any trailing method chain is appended unchanged.

---

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run tests with coverage report
bundle exec rspec --format documentation

# Install the gem locally
bundle exec rake install
```

### Releasing a new version

1. Update `lib/scope_hunter/version.rb`
2. Run `bundle exec rake release`

This creates a git tag, pushes the commit and tag, and publishes the gem to [rubygems.org](https://rubygems.org).

---

## Contributing

Bug reports and pull requests are welcome at [github.com/Ajithxolo/scope_hunter](https://github.com/Ajithxolo/scope_hunter).

1. Fork the repository
2. Create a feature branch: `git checkout -b my-feature`
3. Add tests for your change (we target 90%+ coverage)
4. Make your change and confirm tests pass: `bundle exec rspec`
5. Push and open a pull request

---

## License

MIT — see [LICENSE.txt](LICENSE.txt).
