# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"

module BandMCP
  module Tools
    # Connectivity check. Makes no network call and never reveals the token, only whether one is configured.
    class Ping < MCP::Tool
      tool_name "ping"
      description "Check that the server is up and whether BAND_ACCESS_TOKEN is configured."
      input_schema(properties: {})

      #: (**untyped) -> untyped
      def self.call(**)
        MCP::Tool::Response.new([{ type: "text", text: "pong (BAND_ACCESS_TOKEN set: #{Config.access_token?})" }])
      end
    end
  end
end
