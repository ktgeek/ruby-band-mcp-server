# frozen_string_literal: true

RSpec.describe BandMCP do
  describe ".build_server" do
    subject(:server) { described_class.build_server }

    it "returns an MCP server" do
      expect(server).to be_a(MCP::Server)
    end

    it "registers every tool" do
      expect(server.tools.keys).to contain_exactly("ping", "list_bands")
    end
  end
end
