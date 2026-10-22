# frozen_string_literal: true

# The outcome advice every write tool gives. The including group defines `write_url` (the endpoint the tool posts to)
# and `uncertain_text` (a phrase from the tool's advice), and `call` returns the tool's response.
RSpec.shared_examples "a write with an uncertain outcome" do
  def response_text
    call.content.first[:text]
  end

  it "advises checking first after a timeout" do
    stub_request(:post, write_url).to_timeout

    expect(response_text).to include(uncertain_text)
  end

  it "advises checking first after a 502 with an HTML body" do
    stub_request(:post, write_url).to_return(status: 502, body: "<html>bad gateway</html>")

    expect(response_text).to include(uncertain_text)
  end

  it "reports the uncertain outcome as a tool error" do
    stub_request(:post, write_url).to_return(status: 504, body: "<html>timeout</html>")

    expect(call).to be_error
  end

  it "gives no advice when BAND rejects the write" do
    stub_request(:post, write_url).to_return(status: 403, body: { result_code: 60_400 }.to_json)

    expect(response_text).not_to include(uncertain_text)
  end

  it "gives no advice when a 5xx carries BAND's own failure code" do
    stub_request(:post, write_url).to_return(status: 500, body: { result_code: 60_000 }.to_json)

    expect(response_text).not_to include(uncertain_text)
  end

  it "gives no advice after a 4xx with an HTML body" do
    stub_request(:post, write_url).to_return(status: 404, body: "<html>not found</html>")

    expect(response_text).not_to include(uncertain_text)
  end
end
