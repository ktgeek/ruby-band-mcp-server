# frozen_string_literal: true

# rbs_inline: enabled

require "dotenv"

module BandMCP
  module Config
    ROOT = File.expand_path("../..", __dir__.to_s) #: String

    # Loads the repo's .env by absolute path so the server works from any cwd. Dotenv.load never overrides values
    # already in ENV, which lets an MCP client's `env` setting win over the file.
    #: () -> void
    def self.load_dotenv
      Dotenv.load(File.join(ROOT, ".env"))
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
