# frozen_string_literal: true

RSpec.describe BandMCP::Tools::GetPost do
  let(:post_url) { "https://openapi.band.us/v2.1/band/post" }
  let(:post) do
    { content: "hello", post_key: "p1", band_key: "b1", created_at: 1_484_303_791_000, comment_count: 2,
      emotion_count: 3, post_read_count: 9, author: { name: "Jordan", user_key: "u1", role: "member" },
      photo: { "5110026620" => { url: "http://img/1.jpg" } } }
  end

  def call
    described_class.call(band_key: "b1", post_key: "p1", server_context: nil)
  end

  def result
    JSON.parse(call.content.first[:text])
  end

  before do
    ENV["BAND_ACCESS_TOKEN"] = "token"
    stub_request(:get, post_url).with(query: { band_key: "b1", post_key: "p1" })
                                .to_return(body: { result_code: 1, result_data: { post: post } }.to_json)
  end

  it "is named get_post" do
    expect(described_class.name_value).to eq("get_post")
  end

  it "returns the post's text, keys and counts" do
    expect(result).to include("post_key" => "p1", "band_key" => "b1", "content" => "hello",
                              "comment_count" => 2, "emotion_count" => 3)
  end

  it "returns the author's name only" do
    expect(result["author"]).to eq("Jordan")
  end

  it "converts the epoch-millisecond creation time to ISO 8601" do
    expect(result["created_at"]).to eq("2017-01-13T10:36:31Z")
  end

  it "leaves out photo payloads" do
    expect(result).not_to have_key("photo")
  end

  it "reports a response without a post as a tool error" do
    stub_request(:get, post_url).with(query: hash_including({}))
                                .to_return(body: { result_code: 1, result_data: {} }.to_json)

    expect(call).to be_error
  end

  it "reports a BAND failure as a tool error" do
    stub_request(:get, post_url).with(query: hash_including({})).to_return(
      status: 404, body: { result_code: 60_200, result_data: { message: "Invalid band" } }.to_json
    )

    expect(call).to be_error
  end
end
