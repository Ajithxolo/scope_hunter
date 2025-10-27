# frozen_string_literal: true

require "rubocop/ast"

module ScopeHunter
  module ASTUtils
    extend self

    AR_METHODS = %i[where rewhere joins order limit offset select distinct group having references includes preload].freeze

    # Returns array of steps: [{recv: "User", msg: :where, args: [{status: :active}]}, ...]
    def relation_chain(node)
      return nil unless node&.send_type?

      chain = []
      cur = node
      seen_ar = false

      while cur&.send_type?
        msg  = cur.method_name
        recv = cur.receiver
        args = cur.arguments

        if AR_METHODS.include?(msg) || model_const?(recv)
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

      return nil unless seen_ar && chain.first[:recv] # must start from Model constant
      chain
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
      else :__dynamic__
      end
    end
  end
end
