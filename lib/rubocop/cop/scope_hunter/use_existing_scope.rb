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

        # Class-level project index shared across all cop instances within a run.
        # Accumulated from configured model files plus each file as it is processed.
        @project_index = nil
        @model_files_scanned = false

        class << self
          attr_reader :project_index

          # Resets cross-file state. Call before each RSpec example to prevent pollution.
          def reset_project_index!
            @project_index = nil
            @model_files_scanned = false
          end

          def ensure_project_index!
            @project_index ||= ::ScopeHunter::ScopeIndex.new
          end

          def model_files_scanned?
            @model_files_scanned
          end

          def mark_model_files_scanned!
            @model_files_scanned = true
          end
        end

        def on_new_investigation
          self.class.ensure_project_index!

          unless self.class.model_files_scanned?
            self.class.mark_model_files_scanned!
            scan_model_files
          end

          index_scopes(processed_source.ast)
        end

        def on_send(node)
          chain = ::ScopeHunter::ASTUtils.relation_chain(node)
          return unless chain
          return if dynamic_where_values?(chain)

          model_name = chain.first[:recv]
          return if ignored_model?(model_name)

          sig = ::ScopeHunter::Canonicalizer.signature(chain)
          match = self.class.project_index&.find(sig)
          return unless match

          add_offense(node, message: format(MSG, model: match.model, scope: match.name)) do |corrector|
            replacement = replacement_for(node, match)
            corrector.replace(node.loc.expression, replacement) if replacement
          end
        end

        private

        def scan_model_files
          model_file_paths.each do |path|
            next if current_file?(path)

            src = ::RuboCop::ProcessedSource.new(File.read(path), RUBY_VERSION.to_f, path)
            index_scopes(src.ast)
          rescue StandardError
            next
          end
        end

        def model_file_paths
          patterns = cop_config.fetch("ModelPaths", ["app/models/**/*.rb"])
          Array(patterns).flat_map { |p| Dir.glob(p) }
        end

        def ignored_model?(model_name)
          Array(cop_config.fetch("IgnoreModels", [])).include?(model_name)
        end

        # Returns true when any where/rewhere/where_not step in the chain contains a
        # dynamic value (method call, variable, etc.). Matching against a scope in
        # that case would be a false positive because the runtime value is unknown
        # and may not correspond to what the scope filters for.
        def dynamic_where_values?(chain)
          chain.any? do |step|
            next false unless %i[where rewhere where_not].include?(step[:msg])

            step[:args].any? do |arg|
              arg == :__dynamic__ ||
                (arg.is_a?(Hash) && arg.any? { |_, v| v == :__dynamic__ })
            end
          end
        end

        def current_file?(path)
          return false unless processed_source.path
          File.expand_path(path) == File.expand_path(processed_source.path)
        end

        def index_scopes(ast)
          return unless ast

          ast.each_node(:send) do |send|
            next unless send.method_name == :scope

            name_node = send.arguments[0]
            next unless name_node&.sym_type?

            model = enclosing_class_name(send)
            next unless model
            next if ignored_model?(model)

            lambda_body = send.arguments[1]
            next unless lambda_body&.block_type?

            chain = ::ScopeHunter::ASTUtils.relation_chain(lambda_body.body, require_model: false)
            next unless chain

            sig = ::ScopeHunter::Canonicalizer.signature(chain, model: model)
            self.class.project_index.add(model:, name: name_node.value, signature: sig)
          end
        end

        def enclosing_class_name(node)
          klass = node.each_ancestor(:class).first
          return nil unless klass&.identifier&.const_type?
          klass.identifier.const_name
        end

        def replacement_for(node, match)
          trailing = trailing_after_first_ar(node)
          (["#{match.model}.#{match.name}"] + trailing).join
        rescue StandardError
          nil
        end

        def trailing_after_first_ar(node)
          out = []
          cur = node
          while cur&.send_type?
            seg = "." + cur.method_name.to_s
            seg << "(#{cur.arguments.map(&:source).join(", ")})" unless cur.arguments.empty?
            out.unshift(seg)
            # where.not(...) counts as a single logical step — skip both nodes.
            cur = ::ScopeHunter::ASTUtils.where_not_node?(cur) ? cur.receiver.receiver : cur.receiver
          end
          out.drop(1)
        end
      end
    end
  end
end
