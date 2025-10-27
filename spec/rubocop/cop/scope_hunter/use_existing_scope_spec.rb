# frozen_string_literal: true

require "spec_helper"
require "rubocop"
require "rubocop/cop/scope_hunter/use_existing_scope"

RSpec.describe RuboCop::Cop::ScopeHunter::UseExistingScope, :config do
  let(:config) { RuboCop::Config.new }

  it "flags duplicate query and autocorrects" do
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
end
