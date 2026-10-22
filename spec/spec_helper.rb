# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "band_mcp"
require "webmock/rspec"

Dir[File.join(__dir__, "support/**/*.rb")].each { |file| require file }

RSpec.configure do |config|
  config.expect_with(:rspec) { |expectations| expectations.include_chain_clauses_in_custom_matcher_descriptions = true }
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  # Specs set and delete the token (directly or via Dotenv), so put the real environment back after each one.
  config.around do |example|
    original = ENV.fetch("BAND_ACCESS_TOKEN", nil)
    example.run
  ensure
    ENV["BAND_ACCESS_TOKEN"] = original
  end

  config.order = :random
  Kernel.srand config.seed
end
