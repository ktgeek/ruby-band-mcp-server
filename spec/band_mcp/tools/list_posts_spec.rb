# frozen_string_literal: true

RSpec.describe BandMCP::Tools::ListPosts do
  let(:posts_url) { "https://openapi.band.us/v2/band/posts" }
  let(:token) { "s3cret-token" }
  let(:next_params) { { after: "cursor2", limit: "20", band_key: "b1", access_token: token } }
  let(:items) do
    [{ post_key: "p1", band_key: "b1", content: "first", created_at: 1_484_303_791_000, comment_count: 1,
       emotion_count: 2, author: { name: "Jordan", user_key: "u1" }, photos: [{ url: "http://img/1.jpg" }] },
     { post_key: "p2", band_key: "b1", content: "second", comment_count: 0, emotion_count: 0 }]
  end
  let(:response_data) { { paging: { previous_params: nil, next_params: next_params }, items: items } }

  def call(**args)
    described_class.call(band_key: "b1", server_context: nil, **args)
  end

  def result
    JSON.parse(call.content.first[:text])
  end

  def stub_posts(query: { band_key: "b1", locale: "en_US" })
    stub_request(:get, posts_url).with(query: query)
                                 .to_return(body: { result_code: 1, result_data: response_data }.to_json)
  end

  before do
    ENV["BAND_ACCESS_TOKEN"] = token
    stub_posts
  end

  it "is named list_posts" do
    expect(described_class.name_value).to eq("list_posts")
  end

  it "summarizes each post like get_post does" do
    expect(result["posts"].first).to include("post_key" => "p1", "content" => "first", "author" => "Jordan",
                                             "created_at" => "2017-01-13T10:36:31Z", "comment_count" => 1)
  end

  it "leaves out photo payloads" do
    expect(result["posts"].first).not_to have_key("photos")
  end

  it "returns the next_after cursor" do
    expect(result["next_after"]).to eq("cursor2")
  end

  it "never exposes the access token from next_params" do
    expect(call.content.first[:text]).not_to include(token)
  end

  context "when this is the last page" do
    let(:response_data) { { paging: { previous_params: nil, next_params: nil }, items: items } }

    it "returns a null next_after" do
      expect(result["next_after"]).to be_nil
    end
  end

  context "when next_params has no usable after" do
    let(:next_params) { { after: 7, limit: "20" } }

    it "returns a null next_after" do
      expect(result["next_after"]).to be_nil
    end
  end

  context "when paging is not an object" do
    let(:response_data) { { paging: "oops", items: items } }

    it "still returns the posts with a null next_after" do
      expect(result).to include("next_after" => nil, "posts" => have_attributes(size: 2))
    end
  end

  context "when items contains entries that are not posts" do
    let(:items) { ["junk", nil, { post_key: "p9", content: "ok" }] }

    it "skips them" do
      expect(result["posts"].map { |post| post["post_key"] }).to eq(["p9"])
    end
  end

  context "when items is not a list" do
    let(:response_data) { { paging: nil, items: { post_key: "p1" } } }

    it "reports a tool error rather than an empty band" do
      expect(call).to be_error
    end
  end

  it "rejects empty after and locale values in the input schema" do
    properties = described_class.input_schema_value.to_h[:properties]

    expect(properties.values_at(:after, :locale).map { |property| property[:minLength] }).to eq([1, 1])
  end

  context "when the band has no posts" do
    let(:response_data) { { paging: nil } }

    it "returns an empty list" do
      expect(result["posts"]).to eq([])
    end
  end

  it "sends after and locale when given" do
    stub = stub_posts(query: { band_key: "b1", locale: "ko_KR", after: "cursor1" })
    call(after: "cursor1", locale: "ko_KR")

    expect(stub).to have_been_requested
  end

  it "reports a BAND failure as a tool error" do
    stub_request(:get, posts_url).with(query: hash_including({})).to_return(
      status: 403, body: { result_code: 60_102, result_data: { message: "Not Band member" } }.to_json
    )

    expect(call).to be_error
  end
end
