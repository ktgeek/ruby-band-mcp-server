# frozen_string_literal: true

RSpec.describe BandMCP::Tools::ListBands do
  let(:bands_url) { "https://openapi.band.us/v2.1/bands" }
  let(:bands) do
    [{ name: "Golf Club", band_key: "k1", cover: "http://img/1.jpg", member_count: 100 },
     { name: "Baseball", band_key: "k2", cover: "http://img/2.jpg", member_count: 32 }]
  end

  def call
    described_class.call(server_context: nil)
  end

  before { ENV["BAND_ACCESS_TOKEN"] = "token" }

  it "is named list_bands" do
    expect(described_class.name_value).to eq("list_bands")
  end

  it "returns each band's name, key and member count without the cover" do
    stub_request(:get, bands_url).to_return(body: { result_code: 1, result_data: { bands: bands } }.to_json)

    expect(JSON.parse(call.content.first[:text])).to eq(
      [{ "name" => "Golf Club", "band_key" => "k1", "member_count" => 100 },
       { "name" => "Baseball", "band_key" => "k2", "member_count" => 32 }]
    )
  end

  it "returns an empty list when the user has no bands" do
    stub_request(:get, bands_url).to_return(body: { result_code: 1, result_data: {} }.to_json)

    expect(JSON.parse(call.content.first[:text])).to eq([])
  end

  it "reports a BAND failure as a tool error" do
    stub_request(:get, bands_url).to_return(status: 401, body: { result_code: 10_401 }.to_json)

    expect(call).to be_error
  end

  it "reports a missing token as a tool error" do
    ENV.delete("BAND_ACCESS_TOKEN")

    expect(call.content.first[:text]).to include("BAND_ACCESS_TOKEN is not set")
  end
end
