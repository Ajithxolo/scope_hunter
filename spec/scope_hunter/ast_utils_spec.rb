# frozen_string_literal: true

require "spec_helper"
require "rubocop"
require "scope_hunter/ast_utils"

RSpec.describe ScopeHunter::ASTUtils do
  # Parse a Ruby source snippet into its root AST node.
  def parse(src)
    RuboCop::ProcessedSource.new(src, RUBY_VERSION.to_f).ast
  end

  describe ".relation_chain" do
    it "returns nil for nil input" do
      expect(described_class.relation_chain(nil)).to be_nil
    end

    it "returns nil for a non-send node" do
      expect(described_class.relation_chain(parse(":symbol"))).to be_nil
    end

    it "returns nil when chain contains no AR methods" do
      # User.find(1) — :find is not in AR_METHODS; model const is walked but seen_ar stays false
      expect(described_class.relation_chain(parse("User.find(1)"))).to be_nil
    end

    it "extracts a simple where chain starting from a model constant" do
      result = described_class.relation_chain(parse("User.where(status: :active)"))
      expect(result).not_to be_nil
      expect(result.length).to eq(1)
      expect(result[0]).to include(recv: "User", msg: :where)
      expect(result[0][:args]).to eq([{status: :active}])
    end

    it "extracts chained AR methods" do
      result = described_class.relation_chain(parse("User.where(status: :active).order(:name)"))
      expect(result).not_to be_nil
      expect(result.length).to eq(2)
      expect(result[0][:msg]).to eq(:where)
      expect(result[1][:msg]).to eq(:order)
    end

    it "returns nil when require_model is true and chain has no leading constant" do
      # bare `where(...)` inside a scope lambda — no model receiver
      expect(described_class.relation_chain(parse("where(status: :active)"))).to be_nil
    end

    it "returns chain when require_model is false and no leading constant" do
      result = described_class.relation_chain(parse("where(status: :active)"), require_model: false)
      expect(result).not_to be_nil
      expect(result[0][:recv]).to be_nil
      expect(result[0][:msg]).to eq(:where)
    end

    it "handles joins AR method" do
      result = described_class.relation_chain(parse("User.joins(:posts)"))
      expect(result).not_to be_nil
      expect(result[0][:msg]).to eq(:joins)
    end

    it "handles order with a symbol arg" do
      result = described_class.relation_chain(parse("User.order(:name)"))
      expect(result).not_to be_nil
      expect(result[0][:args]).to eq([:name])
    end
  end

  describe ".model_const?" do
    it "returns true for a const node" do
      expect(described_class.model_const?(parse("User"))).to be_truthy
    end

    it "returns false for a sym node" do
      expect(described_class.model_const?(parse(":active"))).to be_falsy
    end

    it "returns nil for nil" do
      expect(described_class.model_const?(nil)).to be_nil
    end
  end

  describe ".const_name" do
    it "returns the constant name as a string" do
      expect(described_class.const_name(parse("User"))).to eq("User")
    end

    it "returns the scoped constant name" do
      expect(described_class.const_name(parse("Admin::User"))).to eq("Admin::User")
    end
  end

  describe ".literal" do
    it "returns nil for nil input" do
      expect(described_class.literal(nil)).to be_nil
    end

    it "returns a symbol for sym nodes" do
      expect(described_class.literal(parse(":active"))).to eq(:active)
    end

    it "returns a string for str nodes" do
      expect(described_class.literal(parse('"hello"'))).to eq("hello")
    end

    it "returns an integer for int nodes" do
      expect(described_class.literal(parse("42"))).to eq(42)
    end

    it "returns a float for float nodes" do
      expect(described_class.literal(parse("3.14"))).to eq(3.14)
    end

    it "returns true for true nodes" do
      expect(described_class.literal(parse("true"))).to eq(true)
    end

    it "returns false for false nodes" do
      expect(described_class.literal(parse("false"))).to eq(false)
    end

    it "returns a symbolized constant name for const nodes" do
      expect(described_class.literal(parse("MyModel"))).to eq(:MyModel)
    end

    it "returns :__dynamic__ for dynamic/unrecognised nodes" do
      # a bare method call is a send node — not a literal
      expect(described_class.literal(parse("some_method_call"))).to eq(:__dynamic__)
    end
  end

  describe ".hash_to_ruby" do
    it "converts a hash node to a plain Ruby hash" do
      node = parse("{status: :active, role: :admin}")
      expect(described_class.hash_to_ruby(node)).to eq({status: :active, role: :admin})
    end

    it "handles string-keyed hashes" do
      node = parse('{"key" => "value"}')
      expect(described_class.hash_to_ruby(node)).to eq({"key" => "value"})
    end
  end

  describe ".where_not_node?" do
    it "returns true for a where.not(...) send node" do
      node = parse("User.where.not(status: :active)")
      # The outer `not(...)` send is the where.not node
      expect(described_class.where_not_node?(node)).to be true
    end

    it "returns false for a plain where(...) node" do
      node = parse("User.where(status: :active)")
      expect(described_class.where_not_node?(node)).to be false
    end

    it "returns false for a .not(...) call whose receiver is not a bare where" do
      # some_scope.not(...) — receiver has arguments, so it's not the where.not pattern
      node = parse("User.where(x: 1).not(y: 2)")
      expect(described_class.where_not_node?(node)).to be false
    end
  end

  describe ".relation_chain with where.not" do
    it "extracts a where.not chain starting from a model constant" do
      result = described_class.relation_chain(parse("User.where.not(status: :active)"))
      expect(result).not_to be_nil
      expect(result.length).to eq(1)
      expect(result[0]).to include(recv: "User", msg: :where_not)
      expect(result[0][:args]).to eq([{status: :active}])
    end

    it "extracts a bare where.not chain with require_model: false" do
      result = described_class.relation_chain(parse("where.not(status: :active)"), require_model: false)
      expect(result).not_to be_nil
      expect(result[0][:msg]).to eq(:where_not)
      expect(result[0][:recv]).to be_nil
    end

    it "returns nil for bare where.not when require_model is true" do
      expect(described_class.relation_chain(parse("where.not(status: :active)"))).to be_nil
    end
  end

  describe ".unwrap_args" do
    it "unwraps a hash argument" do
      node = parse("where(status: :active)")
      result = described_class.unwrap_args(node.arguments)
      expect(result).to eq([{status: :active}])
    end

    it "unwraps a symbol argument" do
      node = parse("order(:name)")
      result = described_class.unwrap_args(node.arguments)
      expect(result).to eq([:name])
    end

    it "unwraps an integer argument" do
      node = parse("limit(10)")
      result = described_class.unwrap_args(node.arguments)
      expect(result).to eq([10])
    end

    it "unwraps mixed arguments" do
      node = parse("joins(:posts, :comments)")
      result = described_class.unwrap_args(node.arguments)
      expect(result).to eq([:posts, :comments])
    end
  end
end
