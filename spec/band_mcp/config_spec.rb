# frozen_string_literal: true

require "tmpdir"

RSpec.describe BandMCP::Config do
  around do |example|
    original = ENV.fetch("BAND_ACCESS_TOKEN", nil)
    example.run
  ensure
    ENV["BAND_ACCESS_TOKEN"] = original
  end

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
    it "loads the repo's .env by absolute path" do
      allow(Dotenv).to receive(:load)

      described_class.load_dotenv

      expect(Dotenv).to have_received(:load).with(File.join(described_class::ROOT, ".env"))
    end

    context "with a .env file that defines the token" do
      let(:dir) { Dir.mktmpdir }

      before do
        File.write(File.join(dir, ".env"), "BAND_ACCESS_TOKEN=from-file\n")
        stub_const("BandMCP::Config::ROOT", dir)
      end

      after { FileUtils.remove_entry(dir) }

      it "keeps a value already in ENV" do
        ENV["BAND_ACCESS_TOKEN"] = "from-env"

        described_class.load_dotenv

        expect(described_class.access_token).to eq("from-env")
      end

      it "fills in the token when ENV has none" do
        ENV.delete("BAND_ACCESS_TOKEN")

        described_class.load_dotenv

        expect(described_class.access_token).to eq("from-file")
      end
    end
  end
end
