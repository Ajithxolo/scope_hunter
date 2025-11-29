# Scope Hunter

[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%203.2.0-red.svg)](https://www.ruby-lang.org/)
[![RuboCop](https://img.shields.io/badge/rubocop-%3E%3D%201.60-blue.svg)](https://rubocop.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE.txt)

A RuboCop extension that detects duplicate ActiveRecord query chains and suggests replacing them with existing named scopes. Keep your query logic DRY, improve readability, and help your team discover and reuse well-named scopes.

## ✨ Features

- 🔍 **Detects duplicate queries** - Finds ActiveRecord queries that match existing scopes
- 🔄 **Autocorrect support** - Automatically replaces duplicate queries with scope names
- 🎯 **Smart matching** - Normalizes queries to handle hash key order, different syntaxes
- 📦 **Preserves method chains** - Keeps trailing methods like `.order()`, `.limit()` intact
- 🚀 **Zero configuration** - Works out of the box with sensible defaults

## 📦 Installation

Add this line to your application's `Gemfile`:

```ruby
gem 'scope_hunter'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install scope_hunter
```

## 🚀 Usage

### Basic Setup

Add to your `.rubocop.yml`:

```yaml
require:
  - scope_hunter

AllCops:
  NewCops: enable

ScopeHunter/UseExistingScope:
  Enabled: true
```

### Example

**Before:**
```ruby
class User < ApplicationRecord
  scope :active, -> { where(status: :active) }
  scope :published, -> { where(published: true) }
  
  def self.find_active_users
    User.where(status: :active)  # ❌ Duplicate!
  end
  
  def self.recent_published
    User.where(published: true).order(created_at: :desc)  # ❌ Duplicate!
  end
end
```

**After running `rubocop -A`:**
```ruby
class User < ApplicationRecord
  scope :active, -> { where(status: :active) }
  scope :published, -> { where(published: true) }
  
  def self.find_active_users
    User.active  # ✅ Uses scope
  end
  
  def self.recent_published
    User.published.order(created_at: :desc)  # ✅ Uses scope, preserves .order()
  end
end
```

## 📋 What It Detects

The cop flags ActiveRecord queries that match existing scopes:

- ✅ `where()` clauses matching scope definitions
- ✅ `joins()` matching scope definitions  
- ✅ `order()` matching scope definitions
- ✅ Multiple conditions (normalized for hash key order)
- ✅ Queries with trailing methods (preserved during autocorrect)

### Supported Query Methods

- `where` / `rewhere`
- `joins`
- `order`
- `limit`, `offset`
- `select`, `distinct`
- `group`, `having`
- `references`, `includes`, `preload`

## ⚙️ Configuration

### Enable/Disable

```yaml
ScopeHunter/UseExistingScope:
  Enabled: true  # or false to disable
```

### Autocorrect Mode

```yaml
ScopeHunter/UseExistingScope:
  Enabled: true
  Autocorrect: conservative  # Default: conservative
```

### Suggest Partial Matches

```yaml
ScopeHunter/UseExistingScope:
  Enabled: true
  SuggestPartialMatches: true  # Default: true
```

## 🎯 How It Works

1. **Indexing Phase**: Scans your model files and indexes all `scope` definitions
2. **Detection Phase**: For each ActiveRecord query, creates a normalized signature
3. **Matching**: Compares query signatures against indexed scopes
4. **Flagging**: Reports offenses when matches are found
5. **Autocorrect**: Replaces duplicate queries with scope names, preserving trailing methods

### Signature Normalization

The cop normalizes queries to match scopes regardless of:
- Hash key order: `{a: 1, b: 2}` ≡ `{b: 2, a: 1}`
- Hash syntax: `{status: :active}` ≡ `{:status => :active}`
- Query values: Only keys are matched (values are normalized to `?`)

## 📝 Examples

### Basic Where Clause

```ruby
# Detected
scope :active, -> { where(status: :active) }
User.where(status: :active)  # ❌ Flagged

# Autocorrected to
User.active  # ✅
```

### With Trailing Methods

```ruby
# Detected
scope :active, -> { where(status: :active) }
User.where(status: :active).order(:name).limit(10)  # ❌ Flagged

# Autocorrected to
User.active.order(:name).limit(10)  # ✅ Trailing methods preserved
```

### Multiple Conditions

```ruby
# Detected (hash order doesn't matter)
scope :active_published, -> { where(status: :active, published: true) }
User.where(published: true, status: :active)  # ❌ Flagged

# Autocorrected to
User.active_published  # ✅
```

### Joins

```ruby
# Detected
scope :with_comments, -> { joins(:comments) }
Post.joins(:comments)  # ❌ Flagged

# Autocorrected to
Post.with_comments  # ✅
```

### Different Models

```ruby
# Only matches within the same model
class User < ApplicationRecord
  scope :active, -> { where(status: :active) }
end

class Post < ApplicationRecord
  Post.where(status: :active)  # ✅ Not flagged (different model)
end
```

## 🧪 Running RuboCop

```bash
# Check for offenses
bundle exec rubocop

# Check specific files
bundle exec rubocop app/models/

# Autocorrect offenses
bundle exec rubocop -A

# Check only ScopeHunter cop
bundle exec rubocop --only ScopeHunter/UseExistingScope
```

## 🛠️ Development

After checking out the repo, run:

```bash
bin/setup
```

To install dependencies. Then, run:

```bash
bundle exec rspec
```

To run the tests.

To install this gem onto your local machine, run:

```bash
bundle exec rake install
```

To release a new version:

1. Update the version number in `lib/scope_hunter/version.rb`
2. Run `bundle exec rake release`

This will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## 🤝 Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Ajithxolo/scope_hunter.

This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](CODE_OF_CONDUCT.md).

### Development Setup

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/scope_hunter.git`
3. Install dependencies: `bundle install`
4. Run tests: `bundle exec rspec`
5. Create a feature branch: `git checkout -b my-feature`
6. Make your changes and add tests
7. Run tests: `bundle exec rspec`
8. Commit your changes: `git commit -am 'Add feature'`
9. Push to the branch: `git push origin my-feature`
10. Submit a pull request

## 📄 License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## 🙏 Acknowledgments

- Built for the Ruby/Rails community
- Inspired by the need for DRY ActiveRecord code
- Thanks to all contributors!

## 📚 Resources

- [RuboCop Documentation](https://docs.rubocop.org/)
- [Writing Custom Cops](https://docs.rubocop.org/rubocop/development.html)
- [ActiveRecord Scopes Guide](https://guides.rubyonrails.org/active_record_querying.html#scopes)

---

Made with ❤️ for the Ruby community
