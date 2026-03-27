# frozen_string_literal: true

require "spec_helper"
require "scope_hunter/scope_index"

RSpec.describe ScopeHunter::ScopeIndex do
  subject(:index) { described_class.new }

  describe "#find" do
    it "returns nil when the index is empty" do
      expect(index.find("M=User|W={status:?}|J=[]|O=[]")).to be_nil
    end

    it "returns nil for an unknown signature after adds" do
      index.add(model: "User", name: :active, signature: "M=User|W={status:?}|J=[]|O=[]")
      expect(index.find("M=User|W={role:?}|J=[]|O=[]")).to be_nil
    end
  end

  describe "#add" do
    it "stores a scope retrievable by signature" do
      sig = "M=User|W={status:?}|J=[]|O=[]"
      index.add(model: "User", name: :active, signature: sig)

      scope = index.find(sig)
      expect(scope).not_to be_nil
      expect(scope.model).to eq("User")
      expect(scope.name).to eq(:active)
      expect(scope.signature).to eq(sig)
    end

    it "allows multiple scopes with the same signature and returns the first added" do
      sig = "M=User|W={status:?}|J=[]|O=[]"
      index.add(model: "User", name: :active, signature: sig)
      index.add(model: "User", name: :enabled, signature: sig)

      expect(index.find(sig).name).to eq(:active)
    end

    it "stores scopes for different signatures independently" do
      sig_a = "M=User|W={status:?}|J=[]|O=[]"
      sig_b = "M=User|W={role:?}|J=[]|O=[]"
      index.add(model: "User", name: :active, signature: sig_a)
      index.add(model: "User", name: :admin, signature: sig_b)

      expect(index.find(sig_a).name).to eq(:active)
      expect(index.find(sig_b).name).to eq(:admin)
    end
  end

  describe "ScopeHunter::Scope struct" do
    it "has model, name, and signature attributes" do
      scope = ScopeHunter::Scope.new(model: "Post", name: :published, signature: "sig")
      expect(scope.model).to eq("Post")
      expect(scope.name).to eq(:published)
      expect(scope.signature).to eq("sig")
    end
  end
end
