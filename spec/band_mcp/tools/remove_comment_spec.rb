# frozen_string_literal: true

RSpec.describe BandMCP::Tools::RemoveComment do
  let(:remove_url) { "https://openapi.band.us/v2/band/post/comment/remove" }
  let(:keys) { { "band_key" => "b1", "post_key" => "p1", "comment_key" => "c1" } }

  def call
    described_class.call(band_key: "b1", post_key: "p1", comment_key: "c1", server_context: nil)
  end

  def stub_remove
    stub_request(:post, remove_url).with(body: keys)
                                   .to_return(body: { result_code: 1, result_data: { message: "success" } }.to_json)
  end

  before { ENV["BAND_ACCESS_TOKEN"] = "token" }

  it "is named remove_comment" do
    expect(described_class.name_value).to eq("remove_comment")
  end

  it "is marked destructive and not read-only" do
    expect(described_class.annotations_value).to have_attributes(read_only_hint: false, destructive_hint: true)
  end

  it "sends the band_key, post_key and comment_key" do
    stub = stub_remove
    call

    expect(stub).to have_been_requested
  end

  it "confirms which comment was removed" do
    stub_remove

    expect(JSON.parse(call.content.first[:text])).to eq(keys.merge("removed" => true))
  end

  it_behaves_like "a write with an uncertain outcome" do
    let(:write_url) { remove_url }
    let(:uncertain_text) { "may already have been removed" }
  end

  it "reports BAND's refusal as a tool error" do
    stub_request(:post, remove_url).to_return(
      status: 403, body: { result_code: 60_400, result_data: { message: "No delete permission" } }.to_json
    )

    expect(call.content.first[:text]).to include("60400", "No delete permission")
  end
end
