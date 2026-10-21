# frozen_string_literal: true

# rbs_inline: enabled

require "json"
require "mcp"

require_relative "../client"

module BandMCP
  module Tools
    # Shared plumbing for tools that call BAND. Tool classes `extend` this so their `self.call` stays a one-liner and
    # every failure reaches the model as a tool error rather than crashing the server.
    module Helpers
      # Yields a client and turns BandMCP::Error into an MCP error response.
      #: () { (Client) -> untyped } -> untyped
      def with_client
        yield Client.new
      rescue Error => e
        text_response(e.message, error: true)
      end

      #: (untyped data) -> untyped
      def json_response(data)
        text_response(JSON.generate(data))
      end

      #: (String text, ?error: bool) -> untyped
      def text_response(text, error: false)
        MCP::Tool::Response.new([{ type: "text", text: text }], error: error)
      end
    end
  end
end
