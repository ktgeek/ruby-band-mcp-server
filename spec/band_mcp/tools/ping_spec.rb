# frozen_string_literal: true

RSpec.describe BandMCP::Tools::Ping do
  def response_text
    described_class.call(server_context: nil).content.first[:text]
  end

  it "is named ping" do
    expect(described_class.name_value).to eq("ping")
  end

  it "reports that a token is configured" do
    allow(BandMCP::Config).to receive(:access_token?).and_return(true)

    expect(response_text).to eq("pong (BAND_ACCESS_TOKEN set: true)")
  end

  it "does not reveal the token" do
    ENV["BAND_ACCESS_TOKEN"] = "secret"

    expect(response_text).not_to include("secret")
  end

  it "reports that no token is configured" do
    allow(BandMCP::Config).to receive(:access_token?).and_return(false)

    expect(response_text).to eq("pong (BAND_ACCESS_TOKEN set: false)")
  end
end
