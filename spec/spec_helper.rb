# frozen_string_literal: true

require "webmock/rspec"
require "json"
require "tempfile"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "snapapi"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Disable real HTTP requests in tests
  config.before(:each) do
    WebMock.disable_net_connect!
  end

  config.after(:each) do
    WebMock.reset!
  end
end

# Helpers for building stub responses
module SnapAPISpecHelpers
  API_BASE = "https://api.snapapi.pics"

  def stub_post(path, response_body:, status: 200, content_type: "application/json")
    stub_request(:post, "#{API_BASE}#{path}")
      .to_return(
        status: status,
        body: response_body.is_a?(Hash) ? JSON.generate(response_body) : response_body,
        headers: { "Content-Type" => content_type }
      )
  end

  def stub_get(path, response_body:, status: 200, content_type: "application/json")
    stub_request(:get, "#{API_BASE}#{path}")
      .to_return(
        status: status,
        body: response_body.is_a?(Hash) ? JSON.generate(response_body) : response_body,
        headers: { "Content-Type" => content_type }
      )
  end

  def stub_delete(path, response_body:, status: 200)
    stub_request(:delete, "#{API_BASE}#{path}")
      .to_return(
        status: status,
        body: response_body.is_a?(Hash) ? JSON.generate(response_body) : response_body,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def fake_png
    # 1x1 PNG bytes
    "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82"
  end
end

RSpec.configure do |c|
  c.include SnapAPISpecHelpers
end
