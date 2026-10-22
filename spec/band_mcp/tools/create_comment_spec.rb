# frozen_string_literal: true

RSpec.describe BandMCP::Tools::CreateComment do
  let(:create_url) { "https://openapi.band.us/v2/band/post/comment/create" }

  def call
    described_class.call(band_key: "b1", post_key: "p1", content: "nice post", server_context: nil)
  end

  def stub_create(body: anything)
    stub_request(:post, create_url).with(body: body)
                                   .to_return(body: { result_code: 1, result_data: { message: "success" } }.to_json)
  end

  before { ENV["BAND_ACCESS_TOKEN"] = "token" }

  it "is named create_comment" do
    expect(described_class.name_value).to eq("create_comment")
  end

  it "is not marked read-only, destructive or idempotent" do
    expect(described_class.annotations_value)
      .to have_attributes(read_only_hint: false, destructive_hint: false, idempotent_hint: false)
  end

  it "sends the content to BAND as body" do
    stub = stub_create(body: { "band_key" => "b1", "post_key" => "p1", "body" => "nice post" })
    call

    expect(stub).to have_been_requested
  end

  it "confirms the comment was created without inventing a key" do
    stub_create

    expect(JSON.parse(call.content.first[:text])).to eq("band_key" => "b1", "post_key" => "p1", "created" => true)
  end

  it "rejects blank content in the input schema" do
    expect(described_class.input_schema_value.to_h.dig(:properties, :content, :pattern)).to eq("\\S")
  end

  it "warns that the comment may exist after a network failure" do
    stub_request(:post, create_url).to_timeout

    expect(call.content.first[:text]).to include("may still have been added")
  end

  it "does not claim the comment may exist when BAND rejects it" do
    stub_request(:post, create_url).to_return(status: 403, body: { result_code: 60_400 }.to_json)

    expect(call.content.first[:text]).not_to include("may still have been added")
  end

  it "warns that the comment may exist after a 502 with an HTML body" do
    stub_request(:post, create_url).to_return(status: 502, body: "<html>bad gateway</html>")

    expect(call.content.first[:text]).to include("may still have been added")
  end

  it "does not claim the comment may exist after a 4xx with an HTML body" do
    stub_request(:post, create_url).to_return(status: 404, body: "<html>not found</html>")

    expect(call.content.first[:text]).not_to include("may still have been added")
  end

  it "reports a missing comment permission as a tool error" do
    stub_request(:post, create_url).to_return(
      status: 403, body: { result_code: 60_400, result_data: { message: "No comment permission" } }.to_json
    )

    expect(call.content.first[:text]).to include("60400", "No comment permission")
  end
end
