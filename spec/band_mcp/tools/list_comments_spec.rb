# frozen_string_literal: true

RSpec.describe BandMCP::Tools::ListComments do
  let(:comments_url) { "https://openapi.band.us/v2/band/post/comments" }
  let(:token) { "s3cret-token" }
  let(:next_params) { { after: "cursor2", limit: "20", band_key: "b1", post_key: "p1", access_token: token } }
  let(:items) do
    [{ comment_key: "c1", post_key: "p1", band_key: "b1", content: "nice", created_at: 1_484_303_791_000,
       emotion_count: 2, author: { name: "Jordan", user_key: "u1" }, photo: { url: "http://img/1.jpg" } },
     { comment_key: "c2", post_key: "p1", content: "thanks", emotion_count: 0 }]
  end
  let(:response_data) { { paging: { previous_params: nil, next_params: next_params }, items: items } }

  def call(**args)
    described_class.call(band_key: "b1", post_key: "p1", server_context: nil, **args)
  end

  def result
    JSON.parse(call.content.first[:text])
  end

  def stub_comments(query: { band_key: "b1", post_key: "p1" })
    stub_request(:get, comments_url).with(query: query)
                                    .to_return(body: { result_code: 1, result_data: response_data }.to_json)
  end

  before do
    ENV["BAND_ACCESS_TOKEN"] = token
    stub_comments
  end

  it "is named list_comments" do
    expect(described_class.name_value).to eq("list_comments")
  end

  it "is read-only" do
    expect(described_class.annotations_value.read_only_hint).to be(true)
  end

  it "summarizes each comment with its key, text, author and time" do
    expect(result["comments"].first).to eq(
      "comment_key" => "c1", "post_key" => "p1", "content" => "nice", "emotion_count" => 2, "author" => "Jordan",
      "created_at" => "2017-01-13T10:36:31Z"
    )
  end

  it "returns the next_after cursor" do
    expect(result["next_after"]).to eq("cursor2")
  end

  it "never exposes the access token from next_params" do
    expect(call.content.first[:text]).not_to include(token)
  end

  context "when the post has no comments" do
    let(:response_data) { { paging: nil } }

    it "returns an empty list" do
      expect(result).to eq("comments" => [], "next_after" => nil)
    end
  end

  context "when items is not a list" do
    let(:response_data) { { paging: nil, items: { comment_key: "c1" } } }

    it "reports a tool error rather than no comments" do
      expect(call).to be_error
    end
  end

  it "sends after when given" do
    stub = stub_comments(query: { band_key: "b1", post_key: "p1", after: "cursor1" })
    call(after: "cursor1")

    expect(stub).to have_been_requested
  end

  it "asks BAND for the newest comments first when newest_first is true" do
    stub = stub_comments(query: { band_key: "b1", post_key: "p1", sort: "-created_at" })
    call(newest_first: true)

    expect(stub).to have_been_requested
  end

  it "sends no sort by default, which BAND answers oldest first" do
    stub = stub_comments
    call(newest_first: false)

    expect(stub).to have_been_requested
  end

  it "reports a BAND failure as a tool error" do
    stub_request(:get, comments_url).with(query: hash_including({})).to_return(
      status: 404, body: { result_code: 60_200, result_data: { message: "Invalid post" } }.to_json
    )

    expect(call).to be_error
  end
end
