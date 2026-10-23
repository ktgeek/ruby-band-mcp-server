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
require_relative "band_mcp/tools/remove_post"
require_relative "band_mcp/tools/list_comments"
require_relative "band_mcp/tools/create_comment"
require_relative "band_mcp/tools/remove_comment"

module BandMCP
  TOOLS = [
    Tools::Ping, Tools::ListBands, Tools::CreatePost, Tools::GetPost, Tools::ListPosts, Tools::CheckPermissions,
    Tools::RemovePost, Tools::ListComments, Tools::CreateComment, Tools::RemoveComment
  ].freeze #: Array[singleton(MCP::Tool)]

  #: () -> untyped
  def self.build_server
    MCP::Server.new(name: "band-mcp-server", version: VERSION, tools: TOOLS)
  end

  # Entry point shared by the gem's executable and the checkout's launcher.
  #: () -> untyped
  def self.run
    Config.load_dotenv
    MCP::Server::Transports::StdioTransport.new(build_server).open
  end
end
