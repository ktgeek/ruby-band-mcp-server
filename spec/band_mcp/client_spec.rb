# frozen_string_literal: true

RSpec.describe BandMCP::Client do
  subject(:client) { described_class.new(access_token: token) }

  let(:token) { "s3cret-token" }
  let(:bands_url) { "https://openapi.band.us/v2.1/bands" }
  let(:create_url) { "https://openapi.band.us/v2.2/band/post/create" }

  def json_body(result_code:, result_data: {})
    { result_code: result_code, result_data: result_data }.to_json
  end

  def api_error_for(path = "/v2.1/bands")
    client.get(path)
  rescue BandMCP::APIError => e
    e
  end

  describe "#initialize" do
    it "raises when no token is configured" do
      allow(BandMCP::Config).to receive(:access_token).and_return(nil)

      expect { described_class.new }.to raise_error(BandMCP::Error, /BAND_ACCESS_TOKEN is not set/)
    end
  end

  describe "#get" do
    it "returns result_data" do
      stub_request(:get, bands_url).to_return(body: json_body(result_code: 1, result_data: { bands: [] }))

      expect(client.get("/v2.1/bands")).to eq("bands" => [])
    end

    it "sends the bearer token" do
      stub = stub_request(:get, bands_url).with(headers: { "Authorization" => "Bearer #{token}" })
                                          .to_return(body: json_body(result_code: 1))
      client.get("/v2.1/bands")

      expect(stub).to have_been_requested
    end

    it "passes params in the query string" do
      stub = stub_request(:get, "https://openapi.band.us/v2.1/band/post").with(query: { band_key: "b1" })
                                                                         .to_return(body: json_body(result_code: 1))
      client.get("/v2.1/band/post", { "band_key" => "b1" })

      expect(stub).to have_been_requested
    end
  end

  describe "#post" do
    it "returns result_data" do
      stub_request(:post, create_url).to_return(body: json_body(result_code: 1, result_data: { post_key: "p1" }))

      expect(client.post("/v2.2/band/post/create", { "content" => "hi" })).to eq("post_key" => "p1")
    end

    it "sends params form-encoded" do
      stub = stub_request(:post, create_url).with(body: { "band_key" => "b1", "content" => "hello" })
                                            .to_return(body: json_body(result_code: 1))
      client.post("/v2.2/band/post/create", { "band_key" => "b1", "content" => "hello" })

      expect(stub).to have_been_requested
    end
  end

  describe "failures" do
    let(:failure) do
      json_body(result_code: 60_400, result_data: { message: "No write permission", detail: "posting" })
    end

    it "raises an APIError carrying BAND's message and detail" do
      stub_request(:get, bands_url).to_return(status: 403, body: failure)

      expect(api_error_for.message).to eq("BAND API error 60400: No write permission: posting")
    end

    it "exposes the BAND result code" do
      stub_request(:get, bands_url).to_return(status: 403, body: failure)

      expect(api_error_for.code).to eq(60_400)
    end

    it "raises on a non-JSON response" do
      stub_request(:get, bands_url).to_return(status: 502, body: "<html>bad gateway</html>")

      expect { client.get("/v2.1/bands") }.to raise_error(BandMCP::Error, /non-JSON response \(HTTP 502\)/)
    end

    it "raises when the JSON is not an object" do
      stub_request(:get, bands_url).to_return(body: "[]")

      expect { client.get("/v2.1/bands") }.to raise_error(BandMCP::Error, /unexpected response/)
    end

    it "raises a NetworkError without echoing the exception message" do
      stub_request(:get, bands_url).to_raise(Errno::ECONNREFUSED.new("#{bands_url}?access_token=#{token}"))

      expect { client.get("/v2.1/bands") }
        .to raise_error(BandMCP::NetworkError, "BAND request failed (Errno::ECONNREFUSED)")
    end

    it "raises a NetworkError when the connection drops mid-response" do
      stub_request(:get, bands_url).to_raise(EOFError)

      expect { client.get("/v2.1/bands") }.to raise_error(BandMCP::NetworkError, /EOFError/)
    end

    it "raises a NetworkError on a timeout" do
      stub_request(:get, bands_url).to_timeout

      expect { client.get("/v2.1/bands") }.to raise_error(BandMCP::NetworkError, /Timeout/)
    end

    it "raises when the body has no result_code" do
      stub_request(:get, bands_url).to_return(status: 500, body: { error: "boom" }.to_json)

      expect { client.get("/v2.1/bands") }.to raise_error(BandMCP::Error, /unexpected response \(HTTP 500\)/)
    end

    it "never puts the token in an error message" do
      stub_request(:get, bands_url).to_return(status: 401, body: json_body(result_code: 10_401))

      expect(api_error_for.message).not_to include(token)
    end
  end
end
