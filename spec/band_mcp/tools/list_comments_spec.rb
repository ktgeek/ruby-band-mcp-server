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

  it "returns BAND's cursor tagged with the order, so it can only be followed that way" do
    expect(result["next_after"]).to eq("oldest:cursor2")
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

  it "sends BAND's cursor, without a sort, for an oldest-first cursor" do
    stub = stub_comments(query: { band_key: "b1", post_key: "p1", after: "cursor1" })
    call(after: "oldest:cursor1")

    expect(stub).to have_been_requested
  end

  it "sends BAND's cursor with the descending sort for a newest-first cursor" do
    stub = stub_comments(query: { band_key: "b1", post_key: "p1", after: "cursor1", sort: "-created_at" })
    call(after: "newest:cursor1")

    expect(stub).to have_been_requested
  end

  it "takes the order from the cursor when newest_first disagrees" do
    stub = stub_comments(query: { band_key: "b1", post_key: "p1", after: "cursor1", sort: "-created_at" })
    call(after: "newest:cursor1", newest_first: false)

    expect(stub).to have_been_requested
  end

  it "keeps a colon inside BAND's cursor intact" do
    stub = stub_comments(query: { band_key: "b1", post_key: "p1", after: "a:b" })
    call(after: "oldest:a:b")

    expect(stub).to have_been_requested
  end

  it "tags the next cursor as newest when newest_first is true" do
    stub_comments(query: { band_key: "b1", post_key: "p1", sort: "-created_at" })

    expect(JSON.parse(call(newest_first: true).content.first[:text])["next_after"]).to eq("newest:cursor2")
  end

  it "keeps the order of the cursor on the pages after it" do
    stub_comments(query: { band_key: "b1", post_key: "p1", after: "cursor1", sort: "-created_at" })
    page = JSON.parse(call(after: "newest:cursor1").content.first[:text])

    expect(page["next_after"]).to eq("newest:cursor2")
  end

  context "when BAND's cursor is empty" do
    let(:next_params) { { after: "", limit: "20" } }

    it "ends the listing instead of advertising an unusable cursor" do
      expect(result["next_after"]).to be_nil
    end
  end

  it "tells the model how to recover from a refused after value" do
    expect(call(after: "cursor1").content.first[:text]).to include("unchanged", "oldest:", "first page")
  end

  it "refuses an after value that is not a next_after from this tool" do
    expect([call(after: "cursor1"), call(after: "oldest:")]).to all(be_error)
  end

  it "does not call BAND for an after value it refuses" do
    stub = stub_comments(query: hash_including({}))
    call(after: "cursor1")

    expect(stub).not_to have_been_requested
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
