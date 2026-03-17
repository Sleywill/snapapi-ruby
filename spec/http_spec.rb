# frozen_string_literal: true

require "spec_helper"

RSpec.describe SnapAPI::HttpClient do
  subject(:http) do
    described_class.new(api_key: "sk_live_test", base_url: "https://api.snapapi.pics")
  end

  # ---------------------------------------------------------------------------
  # Request headers
  # ---------------------------------------------------------------------------

  describe "request headers" do
    it "sends X-Api-Key header" do
      stub_get("/v1/ping", response_body: { status: "ok" })
      http.get("/v1/ping")
      expect(WebMock).to have_requested(:get, "https://api.snapapi.pics/v1/ping")
        .with(headers: { "X-Api-Key" => "sk_live_test" })
    end

    it "sends Authorization: Bearer header" do
      stub_get("/v1/ping", response_body: { status: "ok" })
      http.get("/v1/ping")
      expect(WebMock).to have_requested(:get, "https://api.snapapi.pics/v1/ping")
        .with(headers: { "Authorization" => "Bearer sk_live_test" })
    end

    it "sends Content-Type: application/json" do
      stub_post("/v1/screenshot", response_body: "\x89PNG", content_type: "image/png")
      http.post("/v1/screenshot", { url: "https://example.com" })
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/screenshot")
        .with(headers: { "Content-Type" => "application/json" })
    end

    it "sends User-Agent with gem version" do
      stub_get("/v1/ping", response_body: { status: "ok" })
      http.get("/v1/ping")
      expect(WebMock).to have_requested(:get, "https://api.snapapi.pics/v1/ping")
        .with(headers: { "User-Agent" => "snapapi-ruby/#{SnapAPI::VERSION}" })
    end
  end

  # ---------------------------------------------------------------------------
  # GET requests
  # ---------------------------------------------------------------------------

  describe "#get" do
    it "returns parsed JSON for JSON responses" do
      stub_get("/v1/usage", response_body: { used: 10, limit: 100 })
      result = http.get("/v1/usage")
      expect(result).to be_a(Hash)
      expect(result["used"]).to eq(10)
    end

    it "returns raw string for binary responses" do
      stub_get("/v1/ping", response_body: "\x89PNG binary", content_type: "image/png")
      result = http.get("/v1/ping")
      expect(result).to be_a(String)
    end
  end

  # ---------------------------------------------------------------------------
  # POST requests
  # ---------------------------------------------------------------------------

  describe "#post" do
    it "serialises body as JSON" do
      stub_post("/v1/screenshot", response_body: "\x89PNG", content_type: "image/png")
      http.post("/v1/screenshot", { url: "https://example.com", format: "png" })
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/screenshot")
        .with { |req|
          body = JSON.parse(req.body)
          body["url"] == "https://example.com" && body["format"] == "png"
        }
    end

    it "returns raw bytes for image/png responses" do
      stub_post("/v1/screenshot", response_body: fake_png, content_type: "image/png")
      result = http.post("/v1/screenshot", { url: "https://example.com" })
      expect(result).to start_with("\x89PNG")
    end

    it "returns raw bytes for application/pdf responses" do
      stub_post("/v1/screenshot", response_body: "%PDF-1.4", content_type: "application/pdf")
      result = http.post("/v1/screenshot", { url: "https://example.com" })
      expect(result).to include("%PDF")
    end

    it "returns raw bytes for video/mp4 responses" do
      stub_post("/v1/video", response_body: "\x00\x00\x00\x20ftyp", content_type: "video/mp4")
      result = http.post("/v1/video", { url: "https://example.com" })
      expect(result).to be_a(String)
    end

    it "returns parsed Hash for JSON responses" do
      stub_post("/v1/extract",
                response_body: { content: "hello", type: "markdown" })
      result = http.post("/v1/extract", { url: "https://example.com" })
      expect(result).to be_a(Hash)
      expect(result["content"]).to eq("hello")
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE requests
  # ---------------------------------------------------------------------------

  describe "#delete" do
    it "performs DELETE and parses response" do
      stub_delete("/v1/storage/files/abc123", response_body: { success: true })
      result = http.delete("/v1/storage/files/abc123")
      expect(result).to be_a(Hash)
      expect(result["success"]).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # Error mapping
  # ---------------------------------------------------------------------------

  describe "error mapping" do
    it "raises AuthenticationError on HTTP 401" do
      stub_request(:get, "https://api.snapapi.pics/v1/usage")
        .to_return(status: 401, body: JSON.generate({ message: "Unauthorized" }),
                   headers: { "Content-Type" => "application/json" })
      expect { http.get("/v1/usage") }.to raise_error(SnapAPI::AuthenticationError)
    end

    it "raises AuthenticationError on HTTP 403" do
      stub_request(:get, "https://api.snapapi.pics/v1/usage")
        .to_return(status: 403, body: JSON.generate({ message: "Forbidden" }),
                   headers: { "Content-Type" => "application/json" })
      expect { http.get("/v1/usage") }.to raise_error(SnapAPI::AuthenticationError)
    end

    it "raises QuotaExceededError on HTTP 402" do
      stub_request(:post, "https://api.snapapi.pics/v1/screenshot")
        .to_return(status: 402, body: JSON.generate({ message: "Quota exceeded" }),
                   headers: { "Content-Type" => "application/json" })
      expect { http.post("/v1/screenshot", {}) }.to raise_error(SnapAPI::QuotaExceededError)
    end

    it "raises ValidationError on HTTP 422" do
      stub_request(:post, "https://api.snapapi.pics/v1/screenshot")
        .to_return(status: 422, body: JSON.generate({ message: "url required" }),
                   headers: { "Content-Type" => "application/json" })
      expect { http.post("/v1/screenshot", {}) }.to raise_error(SnapAPI::ValidationError)
    end

    it "raises RateLimitError on HTTP 429 with Retry-After header" do
      # Stub enough times for initial attempt + all retries
      stub_request(:post, "https://api.snapapi.pics/v1/screenshot")
        .to_return(status: 429,
                   body: JSON.generate({ message: "Too many requests" }),
                   headers: { "Content-Type" => "application/json", "Retry-After" => "2" })
        .times(4)
      expect { http.post("/v1/screenshot", {}) }.to raise_error(SnapAPI::RateLimitError) do |e|
        expect(e.retry_after).to eq(2.0)
      end
    end

    it "raises SnapAPI::Error on HTTP 500 after retries" do
      stub_request(:post, "https://api.snapapi.pics/v1/screenshot")
        .to_return(status: 500, body: JSON.generate({ message: "Internal server error" }),
                   headers: { "Content-Type" => "application/json" })
        .times(4)
      expect { http.post("/v1/screenshot", {}) }.to raise_error(SnapAPI::Error) do |e|
        expect(e.status_code).to eq(500)
      end
    end

    it "raises SnapAPI::Error on HTTP 404" do
      stub_request(:get, "https://api.snapapi.pics/v1/storage/files/missing")
        .to_return(status: 404, body: JSON.generate({ message: "Not found" }),
                   headers: { "Content-Type" => "application/json" })
      expect { http.get("/v1/storage/files/missing") }.to raise_error(SnapAPI::Error) do |e|
        expect(e.status_code).to eq(404)
      end
    end

    it "extracts error message from API JSON body" do
      stub_request(:get, "https://api.snapapi.pics/v1/usage")
        .to_return(status: 401,
                   body: JSON.generate({ message: "API key not found", error: "UNAUTHORIZED" }),
                   headers: { "Content-Type" => "application/json" })
      expect { http.get("/v1/usage") }.to raise_error(SnapAPI::AuthenticationError) do |e|
        expect(e.message).to eq("API key not found")
      end
    end

    it "handles non-JSON error body gracefully" do
      stub_request(:get, "https://api.snapapi.pics/v1/usage")
        .to_return(status: 500, body: "Internal Server Error",
                   headers: { "Content-Type" => "text/plain" })
        .times(4)
      expect { http.get("/v1/usage") }.to raise_error(SnapAPI::Error)
    end
  end

  # ---------------------------------------------------------------------------
  # Retry behaviour (no real sleeps — override sleep)
  # ---------------------------------------------------------------------------

  describe "retry behaviour" do
    let(:fast_http) do
      # Zero retry delay to keep tests fast
      described_class.new(api_key: "sk_live_test", retry_delay: 0)
    end

    before do
      # Suppress sleep inside the retry loop
      allow(fast_http).to receive(:sleep)
    end

    it "retries 3 times on 500 and then raises" do
      stub_request(:post, "https://api.snapapi.pics/v1/screenshot")
        .to_return(status: 500, body: JSON.generate({ message: "error" }),
                   headers: { "Content-Type" => "application/json" })
        .times(4) # 1 initial + 3 retries

      expect { fast_http.post("/v1/screenshot", {}) }.to raise_error(SnapAPI::Error)
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/screenshot").times(4)
    end

    it "succeeds on the second attempt after a 500" do
      stub_request(:post, "https://api.snapapi.pics/v1/screenshot")
        .to_return(status: 500, body: "{}", headers: { "Content-Type" => "application/json" })
        .then
        .to_return(status: 200, body: fake_png, headers: { "Content-Type" => "image/png" })

      result = fast_http.post("/v1/screenshot", { url: "https://example.com" })
      expect(result).to start_with("\x89PNG")
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/screenshot").times(2)
    end

    it "does NOT retry on 401" do
      stub_request(:post, "https://api.snapapi.pics/v1/screenshot")
        .to_return(status: 401, body: JSON.generate({ message: "Unauthorized" }),
                   headers: { "Content-Type" => "application/json" })

      expect { fast_http.post("/v1/screenshot", {}) }.to raise_error(SnapAPI::AuthenticationError)
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/screenshot").once
    end

    it "does NOT retry on 422" do
      stub_request(:post, "https://api.snapapi.pics/v1/screenshot")
        .to_return(status: 422, body: JSON.generate({ message: "Bad input" }),
                   headers: { "Content-Type" => "application/json" })

      expect { fast_http.post("/v1/screenshot", {}) }.to raise_error(SnapAPI::ValidationError)
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/screenshot").once
    end
  end

  # ---------------------------------------------------------------------------
  # Backoff calculation
  # ---------------------------------------------------------------------------

  describe "#compute_backoff (private)" do
    it "doubles delay on each attempt" do
      # Default retry_delay = 0.5
      http_instance = described_class.new(api_key: "x", retry_delay: 0.5)
      expect(http_instance.send(:compute_backoff, 1)).to be_within(0.001).of(0.5)
      expect(http_instance.send(:compute_backoff, 2)).to be_within(0.001).of(1.0)
      expect(http_instance.send(:compute_backoff, 3)).to be_within(0.001).of(2.0)
    end

    it "caps at MAX_RETRY_DELAY (30s)" do
      http_instance = described_class.new(api_key: "x", retry_delay: 0.5)
      expect(http_instance.send(:compute_backoff, 100)).to eq(SnapAPI::HttpClient::MAX_RETRY_DELAY)
    end
  end

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------

  describe "constants" do
    it "exposes DEFAULT_BASE_URL" do
      expect(SnapAPI::HttpClient::DEFAULT_BASE_URL).to eq("https://api.snapapi.pics")
    end

    it "exposes DEFAULT_TIMEOUT" do
      expect(SnapAPI::HttpClient::DEFAULT_TIMEOUT).to be_a(Integer)
      expect(SnapAPI::HttpClient::DEFAULT_TIMEOUT).to eq(60)
    end

    it "exposes DEFAULT_MAX_RETRIES" do
      expect(SnapAPI::HttpClient::DEFAULT_MAX_RETRIES).to eq(3)
    end

    it "exposes DEFAULT_RETRY_DELAY" do
      expect(SnapAPI::HttpClient::DEFAULT_RETRY_DELAY).to eq(0.5)
    end
  end
end
