# frozen_string_literal: true

require "rubocop"
require "scope_hunter/ast_utils"
require "scope_hunter/canonicalizer"
require "scope_hunter/scope_index"

module RuboCop
  module Cop
    module ScopeHunter
      class UseExistingScope < Base
        extend AutoCorrector

        MSG = 'Query matches `%<model>s.%<scope>s`. Use the scope instead.'

        def on_new_investigation
          @index = ::ScopeHunter::ScopeIndex.new
          index_scopes(processed_source.ast)
        end

        def on_send(node)
          chain = ::ScopeHunter::ASTUtils.relation_chain(node)
          return unless chain

          sig = ::ScopeHunter::Canonicalizer.signature(chain)
          match = @index.find(sig)
          return unless match

          add_offense(node, message: format(MSG, model: match.model, scope: match.name)) do |corrector|
            replacement = replacement_for(node, match)
            corrector.replace(node.loc.expression, replacement) if replacement
          end
        end

        private

        def index_scopes(ast)
          return unless ast
          # Find `scope :name, -> { ... }`
          ast.each_node(:send) do |send|
            next unless send.method_name == :scope
            name_node = send.arguments[0]
            next unless name_node&.sym_type?

            model = enclosing_class_name(send)
            next unless model

            # The body is the lambda argument (second argument)
            lambda_body = send.arguments[1]
            next unless lambda_body&.block_type?

            chain = ::ScopeHunter::ASTUtils.relation_chain(lambda_body.body, require_model: false)
            next unless chain

            sig = ::ScopeHunter::Canonicalizer.signature(chain, model: model)
            @index.add(model:, name: name_node.value, signature: sig)
          end
        end

        def enclosing_class_name(node)
          klass = node.each_ancestor(:class).first
          return nil unless klass&.identifier&.const_type?
          klass.identifier.const_name
        end

        # Conservative autocorrect: replace the first AR part with Model.scope, keep trailing chain
        def replacement_for(node, match)
          trailing = trailing_after_first_ar(node)
          ([ "#{match.model}.#{match.name}" ] + trailing).join
        rescue
          nil
        end

        def trailing_after_first_ar(node)
          out = []
          cur = node
          # Gather segments like `.order(...).limit(5)` in reverse
          while cur&.send_type?
            seg = "." + cur.method_name.to_s
            seg << "(#{cur.arguments.map(&:source).join(", ")})" unless cur.arguments.empty?
            out.unshift(seg)
            cur = cur.receiver
          end
          out.drop(1) # drop the first AR call; replaced by scope
        end
      end
    end
  end
end
