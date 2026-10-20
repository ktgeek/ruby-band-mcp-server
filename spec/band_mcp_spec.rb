# frozen_string_literal: true

RSpec.describe BandMCP do
  describe ".build_server" do
    subject(:server) { described_class.build_server }

    it "returns an MCP server" do
      expect(server).to be_a(MCP::Server)
    end

    it "registers the ping tool" do
      expect(server.tools.keys).to contain_exactly("ping")
    end
  end
end
