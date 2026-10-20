# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"

require_relative "band_mcp/version"
require_relative "band_mcp/config"
require_relative "band_mcp/tools/ping"

module BandMCP
  TOOLS = [Tools::Ping].freeze #: Array[singleton(MCP::Tool)]

  #: () -> untyped
  def self.build_server
    MCP::Server.new(name: "band-mcp-server", version: VERSION, tools: TOOLS)
  end
end
