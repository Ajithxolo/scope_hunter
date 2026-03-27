# frozen_string_literal: true

require "rubocop/ast"

module ScopeHunter
  module ASTUtils
    extend self

    AR_METHODS = %i[where rewhere joins order limit offset select distinct group having references includes preload].freeze

    # Returns array of steps: [{recv: "User", msg: :where, args: [{status: :active}]}, ...]
    # Handles the compound `where.not(...)` pattern as a single :where_not step.
    def relation_chain(node, require_model: true)
      return nil unless node&.send_type?

      chain = []
      cur = node
      seen_ar = false

      while cur&.send_type?
        msg  = cur.method_name
        recv = cur.receiver
        args = cur.arguments

        if where_not_node?(cur)
          # `recv` is the bare `.where` call; its receiver is the model (or nil in scope body)
          model_recv = recv.receiver
          chain.unshift({
            recv: model_recv&.const_type? ? const_name(model_recv) : nil,
            msg:  :where_not,
            args: unwrap_args(args)
          })
          seen_ar = true
          cur = model_recv
        elsif AR_METHODS.include?(msg) || model_const?(recv)
          chain.unshift({
            recv: recv&.const_type? ? const_name(recv) : nil,
            msg:  msg,
            args: unwrap_args(args)
          })
          seen_ar ||= AR_METHODS.include?(msg)
          cur = recv
        else
          break
        end
      end

      return nil unless seen_ar
      return nil if require_model && chain.first[:recv].nil? # must start from Model constant
      chain
    end

    def where_not_node?(node)
      node.method_name == :not &&
        node.receiver&.send_type? &&
        node.receiver.method_name == :where &&
        node.receiver.arguments.empty?
    end

    def model_const?(node)
      node&.const_type?
    end

    def const_name(node)
      node.const_name
    rescue
      nil
    end

    def unwrap_args(args)
      args.map { |a| a.hash_type? ? hash_to_ruby(a) : literal(a) }
    end

    def hash_to_ruby(node)
      node.pairs.to_h { |p| [literal(p.key), literal(p.value)] }
    end

    def literal(node)
      case
      when node.nil? then nil
      when node.sym_type? then node.value
      when node.str_type? then node.value
      when node.int_type? then node.value
      when node.float_type? then node.value
      when node.true_type? then true
      when node.false_type? then false
      when node.const_type? then node.const_name.to_sym
      else :__dynamic__ # lvar, ivar, send, etc. — normalized to ? by Canonicalizer,
                        # enabling parameterized scope matching
      end
    end
  end
end
