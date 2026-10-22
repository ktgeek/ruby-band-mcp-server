# frozen_string_literal: true

RSpec.describe BandMCP::Tools::RemovePost do
  let(:remove_url) { "https://openapi.band.us/v2/band/post/remove" }

  def call
    described_class.call(band_key: "b1", post_key: "p1", server_context: nil)
  end

  def stub_remove
    stub_request(:post, remove_url).with(body: { "band_key" => "b1", "post_key" => "p1" })
                                   .to_return(body: { result_code: 1, result_data: { message: "success" } }.to_json)
  end

  before { ENV["BAND_ACCESS_TOKEN"] = "token" }

  it "is named remove_post" do
    expect(described_class.name_value).to eq("remove_post")
  end

  it "is marked destructive and not read-only" do
    expect(described_class.annotations_value).to have_attributes(read_only_hint: false, destructive_hint: true)
  end

  it "sends the band_key and post_key" do
    stub = stub_remove
    call

    expect(stub).to have_been_requested
  end

  it "confirms which post was removed" do
    stub_remove

    expect(JSON.parse(call.content.first[:text])).to eq("band_key" => "b1", "post_key" => "p1", "removed" => true)
  end

  it "warns that the post may be gone after a network failure" do
    stub_request(:post, remove_url).to_timeout

    expect(call.content.first[:text]).to include("may already have been removed")
  end

  it "does not claim the post may be gone when BAND rejects the request" do
    stub_request(:post, remove_url).to_return(status: 403, body: { result_code: 60_400 }.to_json)

    expect(call.content.first[:text]).not_to include("may already have been removed")
  end

  it "warns that the post may be gone after a 502 with an HTML body" do
    stub_request(:post, remove_url).to_return(status: 502, body: "<html>bad gateway</html>")

    expect(call.content.first[:text]).to include("may already have been removed")
  end

  it "does not claim the post may be gone after a 4xx with an HTML body" do
    stub_request(:post, remove_url).to_return(status: 404, body: "<html>not found</html>")

    expect(call.content.first[:text]).not_to include("may already have been removed")
  end

  it "reports a missing delete permission as a tool error" do
    stub_request(:post, remove_url).to_return(
      status: 403, body: { result_code: 60_400, result_data: { message: "No delete permission" } }.to_json
    )

    expect(call).to be_error
  end
end
