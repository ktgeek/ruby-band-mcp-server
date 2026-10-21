# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"

require_relative "band_mcp/version"
require_relative "band_mcp/config"
require_relative "band_mcp/error"
require_relative "band_mcp/client"
require_relative "band_mcp/tools/ping"
require_relative "band_mcp/tools/list_bands"
require_relative "band_mcp/tools/create_post"
require_relative "band_mcp/tools/get_post"
require_relative "band_mcp/tools/list_posts"
require_relative "band_mcp/tools/check_permissions"

module BandMCP
  TOOLS = [
    Tools::Ping, Tools::ListBands, Tools::CreatePost, Tools::GetPost, Tools::ListPosts, Tools::CheckPermissions
  ].freeze #: Array[singleton(MCP::Tool)]

  #: () -> untyped
  def self.build_server
    MCP::Server.new(name: "band-mcp-server", version: VERSION, tools: TOOLS)
  end
end
