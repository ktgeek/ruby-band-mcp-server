# frozen_string_literal: true

require "json"

RSpec.describe BandMCP do
  describe ".run" do
    let(:transport) { instance_double(MCP::Server::Transports::StdioTransport, open: nil) }

    before do
      allow(BandMCP::Config).to receive(:load_dotenv)
      allow(MCP::Server::Transports::StdioTransport).to receive(:new).and_return(transport)
      described_class.run
    end

    it "loads the config" do
      expect(BandMCP::Config).to have_received(:load_dotenv)
    end

    it "serves the tools over stdio" do
      expect(transport).to have_received(:open)
    end
  end

  describe ".build_server" do
    subject(:server) { described_class.build_server }

    it "returns an MCP server" do
      expect(server).to be_a(MCP::Server)
    end

    it "registers every tool" do
      expect(server.tools.keys).to contain_exactly(
        "ping", "list_bands", "create_post", "get_post", "list_posts", "check_permissions",
        "remove_post", "list_comments", "create_comment", "remove_comment"
      )
    end
  end

  # The MCP Registry reads server.json, and matches its name against the Dockerfile's label to prove ownership.
  describe "server.json" do
    subject(:server) { JSON.parse(File.read(File.expand_path("../server.json", __dir__))) }

    let(:dockerfile) { File.read(File.expand_path("../Dockerfile", __dir__)) }

    it "is named by the Dockerfile's registry label" do
      expect(dockerfile).to include(%(io.modelcontextprotocol.server.name="#{server['name']}"))
    end

    it "lists the current gem version" do
      expect(server["version"]).to eq(BandMCP::VERSION)
    end

    it "points at the image tag for that version" do
      expect(server.dig("packages", 0, "identifier")).to end_with(":#{BandMCP::VERSION}")
    end
  end
end
