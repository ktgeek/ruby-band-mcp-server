# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"

require_relative "helpers"

module BandMCP
  module Tools
    class ListBands < MCP::Tool
      extend Helpers

      FIELDS = %w[name band_key member_count].freeze #: Array[String]

      tool_name "list_bands"
      description "List the BANDs the user has joined. Returns each band's name, band_key and member_count; use the " \
                  "band_key to refer to a band in other tools."
      input_schema(properties: {})
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

      #: (**untyped) -> untyped
      def self.call(**)
        with_client do |client|
          bands = client.get("/v2.1/bands").fetch("bands", [])
          json_response(bands.map { |band| band.slice(*FIELDS) })
        end
      end
    end
  end
end
