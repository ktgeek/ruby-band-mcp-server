# frozen_string_literal: true

# rbs_inline: enabled

require "dotenv"

module BandMCP
  module Config
    ROOT = File.expand_path("../..", __dir__.to_s) #: String

    # The per-user config file an installed gem reads, following the XDG base directory convention. It uses .env
    # syntax (KEY=value) but is named for its role.
    #: () -> String
    def self.user_config_path
      config_home = ENV.fetch("XDG_CONFIG_HOME", "")
      # The XDG spec says to ignore a relative path, which would otherwise resolve against the client's cwd.
      config_home = File.join(Dir.home, ".config") unless config_home.start_with?("/")
      File.join(config_home, "band-mcp-server", "config")
    end

    # Loads .env files by absolute path so the server works from any cwd. Dotenv.load never overrides values already
    # in ENV (which lets an MCP client's `env` setting win) or set by an earlier file, so the order is the priority:
    # the checkout's own .env, which an installed gem does not have, then the user's.
    #: () -> void
    def self.load_dotenv
      Dotenv.load(File.join(ROOT, ".env"), user_config_path)
    end

    #: () -> String?
    def self.access_token
      token = ENV.fetch("BAND_ACCESS_TOKEN", nil)
      token unless token.nil? || token.empty?
    end

    #: () -> bool
    def self.access_token?
      !access_token.nil?
    end
  end
end
