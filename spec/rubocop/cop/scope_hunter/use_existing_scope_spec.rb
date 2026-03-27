# frozen_string_literal: true

require "spec_helper"
require "rubocop"
require "rubocop/cop/scope_hunter/use_existing_scope"

RSpec.describe RuboCop::Cop::ScopeHunter::UseExistingScope, :config do
  # Reset the class-level project index before every example so tests are isolated.
  before { described_class.reset_project_index! }

  let(:config) { RuboCop::Config.new }

  # ── Basic detection + autocorrect ──────────────────────────────────────────

  it "flags a duplicate where query and autocorrects to the scope name" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.where(status: :active)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.active`. Use the scope instead.
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.active
        end
      end
    RUBY
  end

  it "flags a rewhere query that matches a scope" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.rewhere(status: :active)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.active`. Use the scope instead.
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.active
        end
      end
    RUBY
  end

  # ── Trailing methods are preserved ─────────────────────────────────────────

  it "preserves trailing methods after the replaced scope call" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.where(status: :active).order(:name)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.active`. Use the scope instead.
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.active.order(:name)
        end
      end
    RUBY
  end

  it "preserves a chain of multiple trailing methods" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.where(status: :active).order(:name).limit(10)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.active`. Use the scope instead.
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.active.order(:name).limit(10)
        end
      end
    RUBY
  end

  # ── No offenses ────────────────────────────────────────────────────────────

  it "does not flag a query that matches no defined scope" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.where(role: :admin)
        end
      end
    RUBY
  end

  it "does not flag non-AR method calls" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        def self.x
          User.find(1)
        end
      end
    RUBY
  end

  it "does not flag scope definitions themselves" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
      end
    RUBY
  end

  # ── Cross-class isolation ──────────────────────────────────────────────────

  it "does not flag a query on a different model even when keys match" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
      end
      class Post < ApplicationRecord
        def self.x
          Post.where(status: :active)
        end
      end
    RUBY
  end

  # ── Joins scope ────────────────────────────────────────────────────────────

  it "flags a joins-based query that matches a scope" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :with_posts, -> { joins(:posts) }
        def self.x
          User.joins(:posts)
          ^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.with_posts`. Use the scope instead.
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        scope :with_posts, -> { joins(:posts) }
        def self.x
          User.with_posts
        end
      end
    RUBY
  end

  # ── Order scope ────────────────────────────────────────────────────────────

  it "flags an order-based query that matches a scope" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :recent, -> { order(created_at: :desc) }
        def self.x
          User.order(created_at: :desc)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.recent`. Use the scope instead.
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        scope :recent, -> { order(created_at: :desc) }
        def self.x
          User.recent
        end
      end
    RUBY
  end

  # ── Multiple scopes ────────────────────────────────────────────────────────

  it "matches the correct scope when multiple scopes are defined" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        scope :admin,  -> { where(role: :admin) }
        def self.x
          User.where(role: :admin)
          ^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.admin`. Use the scope instead.
        end
      end
    RUBY
  end

  it "flags both queries when each matches a different scope" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        scope :admin,  -> { where(role: :admin) }
        def self.x
          User.where(status: :active)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.active`. Use the scope instead.
          User.where(role: :admin)
          ^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.admin`. Use the scope instead.
        end
      end
    RUBY
  end

  # ── Scope with no enclosing class is ignored ───────────────────────────────

  it "does not index a scope defined outside any class" do
    expect_no_offenses(<<~RUBY)
      scope :active, -> { where(status: :active) }
    RUBY
  end

  # ── Non-block lambda / missing args are ignored ────────────────────────────

  it "does not raise on a scope with a non-lambda second argument" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :active, :some_method
      end
    RUBY
  end

  it "does not raise on a scope with no second argument" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :active
      end
    RUBY
  end

  it "does not index a scope whose name is not a symbol" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope "active", -> { where(status: :active) }
        def self.x
          User.where(status: :active)
        end
      end
    RUBY
  end

  it "does not flag when the scope lambda has an empty body" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :empty, -> {}
        def self.x
          User.where(status: :active)
        end
      end
    RUBY
  end

  it "handles an empty source file without raising" do
    expect_no_offenses("")
  end

  # ── where.not() support ───────────────────────────────────────────────────

  it "flags a where.not query that matches a scope" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :inactive, -> { where.not(status: :active) }
        def self.x
          User.where.not(status: :active)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.inactive`. Use the scope instead.
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        scope :inactive, -> { where.not(status: :active) }
        def self.x
          User.inactive
        end
      end
    RUBY
  end

  it "does not confuse where.not with plain where" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.where.not(status: :active)
        end
      end
    RUBY
  end

  it "does not confuse plain where with where.not" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :inactive, -> { where.not(status: :active) }
        def self.x
          User.where(status: :active)
        end
      end
    RUBY
  end

  it "does not flag where.not with dynamic values" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :inactive, -> { where.not(status: :active) }
        def self.x
          User.where.not(status: current_status)
        end
      end
    RUBY
  end

  # ── Dynamic value false-positive prevention ────────────────────────────────

  it "does not flag a query whose where value is a method call (dynamic)" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.where(status: current_status)
        end
      end
    RUBY
  end

  it "does not flag a query whose where value is an instance variable (dynamic)" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.where(status: @default_status)
        end
      end
    RUBY
  end

  it "does not flag a query whose where value is a local variable (dynamic)" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x(s)
          User.where(status: s)
        end
      end
    RUBY
  end

  it "still flags a query with all-literal values matching the scope" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(status: :active) }
        def self.x
          User.where(status: :active)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.active`. Use the scope instead.
        end
      end
    RUBY
  end

  # ── Parameterized scopes ────────────────────────────────────────────────────

  it "flags a query matching a single-parameter scope" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :by_role, ->(role) { where(role: role) }
        def self.admins
          User.where(role: :admin)
          ^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.by_role`. Use the scope instead.
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        scope :by_role, ->(role) { where(role: role) }
        def self.admins
          User.by_role
        end
      end
    RUBY
  end

  it "flags a query matching a multi-parameter scope" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :by_status_and_role, ->(s, r) { where(status: s, role: r) }
        def self.x
          User.where(status: :active, role: :admin)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.by_status_and_role`. Use the scope instead.
        end
      end
    RUBY
  end

  it "does not flag when the key structure differs from a parameterized scope" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :by_role, ->(role) { where(role: role) }
        def self.x
          User.where(status: :active)
        end
      end
    RUBY
  end

  # ── IgnoreModels configuration ────────────────────────────────────────────

  context "when IgnoreModels is configured" do
    let(:config) do
      RuboCop::Config.new(
        "AllCops" => {"DisplayCopNames" => true},
        "ScopeHunter/UseExistingScope" => {
          "Enabled" => true,
          "IgnoreModels" => ["LegacyReport", "AdminAuditLog"]
        }
      )
    end

    it "does not flag a query on an ignored model" do
      expect_no_offenses(<<~RUBY)
        class LegacyReport < ApplicationRecord
          scope :active, -> { where(status: :active) }
          def self.x
            LegacyReport.where(status: :active)
          end
        end
      RUBY
    end

    it "does not index scopes from ignored models" do
      expect_no_offenses(<<~RUBY)
        class LegacyReport < ApplicationRecord
          scope :active, -> { where(status: :active) }
        end
        class User < ApplicationRecord
          def self.x
            User.where(status: :active)
          end
        end
      RUBY
    end

    it "still flags queries on non-ignored models" do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          scope :active, -> { where(status: :active) }
          def self.x
            User.where(status: :active)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.active`. Use the scope instead.
          end
        end
      RUBY
    end
  end

  # ── Cross-file scope detection ─────────────────────────────────────────────

  context "when scopes are defined in a separate model file" do
    let(:tmp_dir) { Dir.mktmpdir }
    after { FileUtils.remove_entry(tmp_dir) }

    let(:config) do
      RuboCop::Config.new(
        "AllCops" => {"DisplayCopNames" => true},
        "ScopeHunter/UseExistingScope" => {
          "Enabled" => true,
          "ModelPaths" => ["#{tmp_dir}/*.rb"]
        }
      )
    end

    before do
      File.write(File.join(tmp_dir, "user.rb"), <<~RUBY)
        class User < ApplicationRecord
          scope :active, -> { where(status: :active) }
        end
      RUBY
    end

    it "flags a query in a controller that matches a scope from a model file" do
      expect_offense(<<~RUBY)
        class UsersController
          def index
            User.where(status: :active)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.active`. Use the scope instead.
          end
        end
      RUBY
    end

    it "autocorrects a cross-file match" do
      expect_offense(<<~RUBY)
        User.where(status: :active)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.active`. Use the scope instead.
      RUBY

      expect_correction(<<~RUBY)
        User.active
      RUBY
    end

    it "does not flag when the query does not match any scope in the model file" do
      expect_no_offenses(<<~RUBY)
        class UsersController
          def index
            User.where(role: :admin)
          end
        end
      RUBY
    end

    it "detects scopes from multiple model files" do
      File.write(File.join(tmp_dir, "post.rb"), <<~RUBY)
        class Post < ApplicationRecord
          scope :published, -> { where(published: true) }
        end
      RUBY

      expect_offense(<<~RUBY)
        Post.where(published: true)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `Post.published`. Use the scope instead.
      RUBY
    end

    it "skips model files that cannot be read" do
      File.write(File.join(tmp_dir, "broken.rb"), "class Broken < ; end")
      expect_no_offenses(<<~RUBY)
        Post.where(published: true)
      RUBY
    end

    it "does not double-index when the analyzed file is also a model file" do
      # Passing the model file's path as the source file ensures current_file? returns
      # true so scan_model_files skips it — scopes are still indexed via index_scopes.
      model_path = File.join(tmp_dir, "user.rb")

      expect_offense(<<~RUBY, model_path)
        class User < ApplicationRecord
          scope :active, -> { where(status: :active) }
          def self.x
            User.where(status: :active)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^ ScopeHunter/UseExistingScope: Query matches `User.active`. Use the scope instead.
          end
        end
      RUBY
    end
  end
end
