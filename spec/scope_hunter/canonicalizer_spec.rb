# frozen_string_literal: true

require "spec_helper"
require "scope_hunter/canonicalizer"

RSpec.describe ScopeHunter::Canonicalizer do
  describe ".signature" do
    it "normalizes where hash key order (existing test)" do
      chain_a = [{recv: "User", msg: :where, args: [{a: 1, b: 2}]}]
      chain_b = [{recv: "User", msg: :where, args: [{b: 9, a: 7}]}]
      expect(described_class.signature(chain_a)).to eq(described_class.signature(chain_b))
    end

    it "includes the model from the chain recv" do
      chain = [{recv: "User", msg: :where, args: [{status: :active}]}]
      expect(described_class.signature(chain)).to start_with("M=User|")
    end

    it "prefers an explicit model param over the chain recv" do
      chain = [{recv: "User", msg: :where, args: [{status: :active}]}]
      sig = described_class.signature(chain, model: "Admin")
      expect(sig).to start_with("M=Admin|")
    end

    it "produces a stable where signature ignoring values" do
      chain = [{recv: "User", msg: :where, args: [{status: :active}]}]
      expect(described_class.signature(chain)).to eq("M=User|W={status:?}|J=[]|O=[]")
    end

    it "treats rewhere the same as where" do
      chain_w = [{recv: "User", msg: :where,   args: [{status: :active}]}]
      chain_r = [{recv: "User", msg: :rewhere, args: [{status: :active}]}]
      expect(described_class.signature(chain_w)).to eq(described_class.signature(chain_r))
    end

    it "merges multiple where steps" do
      chain = [
        {recv: "User", msg: :where, args: [{status: :active}]},
        {recv: nil,    msg: :where, args: [{role: :admin}]}
      ]
      sig = described_class.signature(chain)
      expect(sig).to include("W={role:?,status:?}")
    end

    it "includes sorted joins in the signature" do
      chain = [
        {recv: "User", msg: :where, args: [{status: :active}]},
        {recv: nil,    msg: :joins, args: [:posts]}
      ]
      expect(described_class.signature(chain)).to include("J=[posts]")
    end

    it "sorts multiple joins alphabetically" do
      chain = [{recv: "User", msg: :joins, args: [:posts, :comments]}]
      expect(described_class.signature(chain)).to include("J=[comments,posts]")
    end

    it "includes order from hash form" do
      chain = [{recv: "User", msg: :order, args: [{created_at: :desc}]}]
      expect(described_class.signature(chain)).to include("O=[(created_at,desc)]")
    end

    it "includes order from symbol form" do
      chain = [{recv: "User", msg: :order, args: [:name]}]
      expect(described_class.signature(chain)).to include("O=[(name,asc)]")
    end

    it "includes order from string form" do
      chain = [{recv: "User", msg: :order, args: ["created_at"]}]
      expect(described_class.signature(chain)).to include("O=[(created_at,asc)]")
    end

    it "appends WN component for where_not steps" do
      chain = [{recv: "User", msg: :where_not, args: [{status: :active}]}]
      expect(described_class.signature(chain)).to eq("M=User|W={}|J=[]|O=[]|WN={status:?}")
    end

    it "combines where and where_not in the same signature" do
      chain = [
        {recv: "User", msg: :where,     args: [{role: :admin}]},
        {recv: nil,    msg: :where_not, args: [{deleted: true}]}
      ]
      sig = described_class.signature(chain)
      expect(sig).to include("W={role:?}")
      expect(sig).to include("WN={deleted:?}")
    end

    it "omits WN component when there are no where_not steps" do
      chain = [{recv: "User", msg: :where, args: [{status: :active}]}]
      expect(described_class.signature(chain)).not_to include("WN=")
    end

    it "ignores non-where/joins/order steps in signature" do
      # limit, offset, select etc. do not affect the signature
      chain = [
        {recv: "User", msg: :where, args: [{status: :active}]},
        {recv: nil,    msg: :limit, args: [10]}
      ]
      expect(described_class.signature(chain)).to eq("M=User|W={status:?}|J=[]|O=[]")
    end
  end

  describe ".normalize_hash" do
    it "returns an empty hash for nil" do
      expect(described_class.normalize_hash(nil)).to eq({})
    end

    it "returns an empty hash for a non-Hash value (e.g. a dynamic sentinel)" do
      expect(described_class.normalize_hash(:__dynamic__)).to eq({})
    end

    it "returns an empty hash for an empty input" do
      expect(described_class.normalize_hash({})).to eq({})
    end

    it "converts all values to the ? sentinel" do
      result = described_class.normalize_hash({a: 1, b: "hello"})
      expect(result.values).to all(eq(:"?"))
    end

    it "converts symbol keys to strings" do
      result = described_class.normalize_hash({status: :active})
      expect(result.keys).to all(be_a(String))
      expect(result).to eq({"status" => :"?"})
    end

    it "preserves string keys as strings" do
      result = described_class.normalize_hash({"role" => :admin})
      expect(result).to eq({"role" => :"?"})
    end
  end

  describe ".normalize_list" do
    it "returns an empty array for nil" do
      expect(described_class.normalize_list(nil)).to eq([])
    end

    it "converts symbols to strings" do
      expect(described_class.normalize_list([:posts, :comments])).to eq(["posts", "comments"])
    end

    it "flattens nested arrays" do
      expect(described_class.normalize_list([[:posts, :tags], :comments])).to eq(["posts", "tags", "comments"])
    end

    it "compacts nil values" do
      expect(described_class.normalize_list([:posts, nil, :comments])).to eq(["posts", "comments"])
    end
  end

  describe ".normalize_order" do
    it "returns empty array for an unrecognised first arg" do
      expect(described_class.normalize_order([nil])).to eq([])
    end

    it "handles hash form with explicit direction" do
      result = described_class.normalize_order([{created_at: :desc}])
      expect(result).to eq([["created_at", "desc"]])
    end

    it "handles hash form with multiple columns" do
      result = described_class.normalize_order([{name: :asc, created_at: :desc}])
      expect(result).to include(["name", "asc"], ["created_at", "desc"])
    end

    it "handles symbol form (defaults to asc)" do
      expect(described_class.normalize_order([:name])).to eq([["name", "asc"]])
    end

    it "handles string form (defaults to asc)" do
      expect(described_class.normalize_order(["created_at"])).to eq([["created_at", "asc"]])
    end

    it "handles nil direction value in hash form" do
      result = described_class.normalize_order([{created_at: nil}])
      expect(result).to eq([["created_at", nil]])
    end
  end
end
