# frozen_string_literal: true

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
end
