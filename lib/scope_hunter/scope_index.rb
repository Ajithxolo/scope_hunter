# frozen_string_literal: true

module ScopeHunter
    Scope = Struct.new(:model, :name, :signature, keyword_init: true)
  
    class ScopeIndex
      def initialize
        @by_signature = {}
      end
  
      def add(model:, name:, signature:)
        (@by_signature[signature] ||= []) << Scope.new(model:, name:, signature:)
      end
  
      def find(signature)
        Array(@by_signature[signature]).first
      end
    end
  end
  