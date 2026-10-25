# frozen_string_literal: true

require_relative "lib/band_mcp/version"

Gem::Specification.new do |spec|
  spec.name = "band-mcp-server"
  spec.version = BandMCP::VERSION
  spec.authors = ["Keith T. Garner"]
  spec.email = ["kgarner@kgarner.com"]

  spec.summary = "MCP server for the BAND Open API"
  spec.description = "A Model Context Protocol server, served over stdio, that lets MCP clients list bands and read, " \
                     "post, and comment on BAND posts through the BAND Open API."
  spec.homepage = "https://github.com/ktgeek/ruby-band-mcp-server"
  spec.license = "GPL-3.0-only"
  spec.required_ruby_version = ">= 4.0"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb"] + %w[exe/band-mcp-server LICENSE README.md CHANGELOG.md API_DISCREPANCIES.md]
  spec.bindir = "exe"
  spec.executables = ["band-mcp-server"]

  spec.add_dependency "dotenv", "~> 3.2"
  spec.add_dependency "mcp", "~> 1.8"
end
