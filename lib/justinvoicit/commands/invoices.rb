# frozen_string_literal: true

require "json"
require_relative "base"

module Justinvoicit
  module Commands
    # `justinvoicit invoices ...`
    class Invoices < Base
      STATUSES = %w[draft pending paid].freeze

      desc "list", "List your invoices, newest due date first"
      method_option :status, type: :string, enum: STATUSES, desc: "Only show invoices with this status"
      method_option :limit, type: :numeric, desc: "Show at most this many invoices"
      method_option :json, type: :boolean, default: false, desc: "Print raw JSON (for scripts)"
      def list
        with_errors do
          invoices = api.invoices
          invoices = invoices.select { |i| i["status"] == options[:status] } if options[:status]
          invoices = invoices.first(options[:limit]) if options[:limit]

          if options[:json]
            puts JSON.pretty_generate(invoices)
          elsif invoices.empty?
            say "No invoices found."
          else
            print_table([%w[# NAME CLIENT AMOUNT STATUS DUE]] + invoices.map { |i| row(i) })
            say "\n#{invoices.size} invoice(s)"
          end
        end
      end

      private

      def row(invoice)
        [
          invoice["identifier"],
          invoice["name"],
          invoice.dig("client", "full_name") || "-",
          format("%<amount>.2f %<currency>s", amount: invoice["amount"].to_f, currency: invoice["currency"].to_s.upcase),
          invoice["status"],
          invoice["due_date"] || "-"
        ]
      end
    end
  end
end
