# frozen_string_literal: true

require "spec_helper"
require "scope_hunter/canonicalizer"

RSpec.describe ScopeHunter::Canonicalizer do
  it "normalizes where hash order" do
    chain_a = [{ recv: "User", msg: :where, args: [{ a: 1, b: 2 }] }]
    chain_b = [{ recv: "User", msg: :where, args: [{ b: 9, a: 7 }] }]

    expect(described_class.signature(chain_a)).to eq(described_class.signature(chain_b))
  end
end
