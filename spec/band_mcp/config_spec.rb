# frozen_string_literal: true

require "tmpdir"

RSpec.describe BandMCP::Config do
  describe ".access_token" do
    it "returns the token from ENV" do
      ENV["BAND_ACCESS_TOKEN"] = "secret"

      expect(described_class.access_token).to eq("secret")
    end

    it "is nil when the variable is unset" do
      ENV.delete("BAND_ACCESS_TOKEN")

      expect(described_class.access_token).to be_nil
    end

    it "is nil when the variable is empty" do
      ENV["BAND_ACCESS_TOKEN"] = ""

      expect(described_class.access_token).to be_nil
    end
  end

  describe ".access_token?" do
    it "is true when a token is set" do
      ENV["BAND_ACCESS_TOKEN"] = "secret"

      expect(described_class).to be_access_token
    end

    it "is false when no token is set" do
      ENV.delete("BAND_ACCESS_TOKEN")

      expect(described_class).not_to be_access_token
    end
  end

  describe ".load_dotenv" do
    it "loads the repo's .env, then the user's, by absolute path" do
      allow(Dotenv).to receive(:load)

      described_class.load_dotenv

      expect(Dotenv).to have_received(:load)
        .with(File.join(described_class::ROOT, ".env"), described_class.user_config_path)
    end

    context "with .env files that define the token" do
      let(:root) { Dir.mktmpdir }
      let(:config_home) { Dir.mktmpdir }

      before do
        stub_const("BandMCP::Config::ROOT", root)
        ENV["XDG_CONFIG_HOME"] = config_home
        FileUtils.mkdir_p(File.dirname(described_class.user_config_path))
        File.write(described_class.user_config_path, "BAND_ACCESS_TOKEN=from-user-file\n")
      end

      after do
        FileUtils.remove_entry(root)
        FileUtils.remove_entry(config_home)
      end

      it "keeps a value already in ENV" do
        ENV["BAND_ACCESS_TOKEN"] = "from-env"

        described_class.load_dotenv

        expect(described_class.access_token).to eq("from-env")
      end

      it "fills in the token from the user's file when ENV has none" do
        ENV.delete("BAND_ACCESS_TOKEN")

        described_class.load_dotenv

        expect(described_class.access_token).to eq("from-user-file")
      end

      it "prefers the checkout's .env over the user's file" do
        File.write(File.join(root, ".env"), "BAND_ACCESS_TOKEN=from-repo-file\n")
        ENV.delete("BAND_ACCESS_TOKEN")

        described_class.load_dotenv

        expect(described_class.access_token).to eq("from-repo-file")
      end
    end
  end

  describe ".user_config_path" do
    it "lives under XDG_CONFIG_HOME when set" do
      ENV["XDG_CONFIG_HOME"] = "/xdg"

      expect(described_class.user_config_path).to eq("/xdg/band-mcp-server/config")
    end

    it "falls back to ~/.config when XDG_CONFIG_HOME is empty or relative" do
      ENV["XDG_CONFIG_HOME"] = "relative/dir"

      expect(described_class.user_config_path).to eq(File.join(Dir.home, ".config", "band-mcp-server", "config"))
    end
  end
end
