# frozen_string_literal: true

RSpec.describe BandMCP::Tools::CheckPermissions do
  let(:permissions_url) { "https://openapi.band.us/v2/band/permissions" }
  let(:requested) { %w[posting commenting contents_deletion] }
  let(:result_data) { { permissions: %w[posting commenting] } }

  def call
    described_class.call(band_key: "b1", permissions: requested, server_context: nil)
  end

  def result
    JSON.parse(call.content.first[:text])
  end

  before do
    ENV["BAND_ACCESS_TOKEN"] = "token"
    stub_request(:get, permissions_url)
      .with(query: { band_key: "b1", permissions: "posting,commenting,contents_deletion" })
      .to_return(body: { result_code: 1, result_data: result_data }.to_json)
  end

  it "is named check_permissions" do
    expect(described_class.name_value).to eq("check_permissions")
  end

  it "is read-only" do
    expect(described_class.annotations_value.read_only_hint).to be(true)
  end

  it "splits the requested permissions into granted and denied" do
    expect(result).to eq("granted" => %w[posting commenting], "denied" => %w[contents_deletion])
  end

  context "when BAND uses the singular key from its docs example" do
    let(:result_data) { { permission: %w[posting] } }

    it "still reads the granted permissions" do
      expect(result).to include("granted" => %w[posting])
    end
  end

  context "when BAND grants everything" do
    let(:result_data) { { permissions: requested } }

    it "denies nothing" do
      expect(result).to eq("granted" => requested, "denied" => [])
    end
  end

  context "when BAND grants nothing" do
    let(:result_data) { { permissions: [] } }

    it "denies everything requested" do
      expect(result).to eq("granted" => [], "denied" => requested)
    end
  end

  context "when BAND returns no permission list" do
    let(:result_data) { {} }

    it "reports a tool error instead of denying everything" do
      expect(call).to be_error
    end
  end

  context "when the permission list is not an array" do
    let(:result_data) { { permissions: "posting" } }

    it "reports a tool error" do
      expect(call).to be_error
    end
  end

  it "reports a BAND failure as a tool error" do
    stub_request(:get, permissions_url).with(query: hash_including({})).to_return(
      status: 404, body: { result_code: 60_200, result_data: { message: "Invalid band" } }.to_json
    )

    expect(call).to be_error
  end
end
