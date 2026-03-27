# frozen_string_literal: true

module ScopeHunter
    module Canonicalizer
      extend self
  
      # chain: array of {recv:, msg:, args:}
      # output: stable signature string
      def signature(chain, model: nil)
        state = { model: model, where: {}, where_not: {}, joins: [], order: [] }

        chain.each do |step|
          state[:model] ||= step[:recv] if step[:recv].is_a?(String)

          case step[:msg]
          when :where, :rewhere
            state[:where].merge!(normalize_hash(step[:args].first))
          when :where_not
            state[:where_not].merge!(normalize_hash(step[:args].first))
          when :joins
            state[:joins] |= normalize_list(step[:args])
            state[:joins].sort!
          when :order
            state[:order] += normalize_order(step[:args])
          end
        end

        w  = state[:where].sort_by(&:first).map { |k, _| "#{k}:?" }.join(",")
        wn = state[:where_not].sort_by(&:first).map { |k, _| "#{k}:?" }.join(",")
        j  = state[:joins].join(",")
        o  = state[:order].map { |(c, d)| "(#{c},#{d || "asc"})" }.join(",")

        sig = "M=#{state[:model]}|W={#{w}}|J=[#{j}]|O=[#{o}]"
        sig += "|WN={#{wn}}" unless wn.empty?
        sig
      end
  
      def normalize_hash(obj)
        h = obj.is_a?(Hash) ? obj : {}
        h.transform_keys { |k| k.to_s }.transform_values { |_| :"?" }
      end
  
      def normalize_list(args)
        Array(args).flatten.compact.map(&:to_s)
      end
  
      def normalize_order(args)
        first = args.first
        case first
        when Hash
          first.map { |k, v| [k.to_s, v&.to_s] }
        when Symbol, String
          [[first.to_s, "asc"]]
        else
          []
        end
      end
    end
  end
  