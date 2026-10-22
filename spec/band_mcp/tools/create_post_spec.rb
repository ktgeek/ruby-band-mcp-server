# frozen_string_literal: true

RSpec.describe BandMCP::Tools::CreatePost do
  let(:create_url) { "https://openapi.band.us/v2.2/band/post/create" }

  def call(**args)
    described_class.call(band_key: "b1", content: "hello", server_context: nil, **args)
  end

  def stub_create(body: anything)
    stub_request(:post, create_url).with(body: body).to_return(
      body: { result_code: 1, result_data: { band_key: "b1", post_key: "p1" } }.to_json
    )
  end

  before { ENV["BAND_ACCESS_TOKEN"] = "token" }

  it "is named create_post" do
    expect(described_class.name_value).to eq("create_post")
  end

  it "is not marked read-only" do
    expect(described_class.annotations_value.read_only_hint).to be(false)
  end

  it "returns the band_key and post_key" do
    stub_create

    expect(JSON.parse(call.content.first[:text])).to eq("band_key" => "b1", "post_key" => "p1")
  end

  it "does not push-notify by default" do
    stub = stub_create(body: hash_including("do_push" => "false"))
    call

    expect(stub).to have_been_requested
  end

  it "push-notifies when asked" do
    stub = stub_create(body: hash_including("do_push" => "true"))
    call(do_push: true)

    expect(stub).to have_been_requested
  end

  it "sends the band_key and content" do
    stub = stub_create(body: hash_including("band_key" => "b1", "content" => "hello"))
    call

    expect(stub).to have_been_requested
  end

  it_behaves_like "a write with an uncertain outcome" do
    let(:write_url) { create_url }
    let(:uncertain_text) { "may still have been published" }
  end

  it "rejects blank content in the input schema" do
    expect(described_class.input_schema_value.to_h.dig(:properties, :content, :pattern)).to eq("\\S")
  end

  it "reports a missing write permission as a tool error" do
    stub_request(:post, create_url).to_return(
      status: 403, body: { result_code: 60_400, result_data: { message: "No write permission" } }.to_json
    )

    expect(call.content.first[:text]).to include("60400", "No write permission")
  end
end
