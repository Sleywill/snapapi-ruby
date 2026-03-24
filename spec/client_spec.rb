# frozen_string_literal: true

require "spec_helper"

RSpec.describe SnapAPI::Client do
  let(:api_key) { "sk_live_test_key" }
  subject(:client) { described_class.new(api_key: api_key) }

  # ---------------------------------------------------------------------------
  # Initialization
  # ---------------------------------------------------------------------------

  describe "#initialize" do
    it "raises ArgumentError when api_key is nil" do
      expect { described_class.new(api_key: nil) }.to raise_error(ArgumentError, /api_key is required/)
    end

    it "raises ArgumentError when api_key is empty string" do
      expect { described_class.new(api_key: "") }.to raise_error(ArgumentError, /api_key is required/)
    end

    it "accepts a valid api_key" do
      expect { described_class.new(api_key: "sk_live_abc") }.not_to raise_error
    end

    it "uses api_key from configuration block when not given directly" do
      SnapAPI.configure { |c| c.api_key = "sk_live_from_config" }
      stub_get("/v1/ping", response_body: { status: "ok" })
      c = described_class.new
      c.ping
      expect(WebMock).to have_requested(:get, "https://api.snapapi.pics/v1/ping")
        .with(headers: { "X-Api-Key" => "sk_live_from_config" })
    end

    it "prefers direct api_key over configuration" do
      SnapAPI.configure { |c| c.api_key = "sk_live_from_config" }
      stub_get("/v1/ping", response_body: { status: "ok" })
      c = described_class.new(api_key: "sk_live_direct")
      c.ping
      expect(WebMock).to have_requested(:get, "https://api.snapapi.pics/v1/ping")
        .with(headers: { "X-Api-Key" => "sk_live_direct" })
    end

    it "raises when neither direct nor configured api_key is set" do
      SnapAPI.reset_configuration!
      expect { described_class.new }.to raise_error(ArgumentError, /api_key is required/)
    end
  end

  # ---------------------------------------------------------------------------
  # Configuration
  # ---------------------------------------------------------------------------

  describe "SnapAPI.configure" do
    it "allows setting api_key via block" do
      SnapAPI.configure do |c|
        c.api_key = "sk_live_block"
      end
      expect(SnapAPI.configuration.api_key).to eq("sk_live_block")
    end

    it "allows setting custom base_url" do
      SnapAPI.configure do |c|
        c.base_url = "https://custom.api.example.com"
      end
      expect(SnapAPI.configuration.base_url).to eq("https://custom.api.example.com")
    end

    it "reset_configuration! restores defaults" do
      SnapAPI.configure { |c| c.api_key = "test"; c.timeout = 120 }
      SnapAPI.reset_configuration!
      expect(SnapAPI.configuration.api_key).to be_nil
      expect(SnapAPI.configuration.timeout).to eq(60)
    end
  end

  # ---------------------------------------------------------------------------
  # Screenshot
  # ---------------------------------------------------------------------------

  describe "#screenshot" do
    it "returns raw PNG bytes for a URL" do
      stub_post("/v1/screenshot", response_body: fake_png, content_type: "image/png")
      result = client.screenshot(url: "https://example.com")
      expect(result).to be_a(String)
      expect(result).to start_with("\x89PNG")
    end

    it "raises ArgumentError when no url/html/markdown given" do
      expect { client.screenshot }.to raise_error(ArgumentError, /url, html, or markdown/)
    end

    it "sends correct JSON payload" do
      stub_post("/v1/screenshot", response_body: fake_png, content_type: "image/png")
      client.screenshot(url: "https://example.com", format: "jpeg", full_page: true)
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/screenshot")
        .with { |req| JSON.parse(req.body)["url"] == "https://example.com" }
    end

    it "returns ScreenshotResult for storage responses" do
      stub_post("/v1/screenshot",
                response_body: { url: "https://cdn.snapapi.pics/abc.png", status: "stored" })
      result = client.screenshot(url: "https://example.com", storage: { destination: "snapapi" })
      expect(result).to be_a(SnapAPI::ScreenshotResult)
      expect(result.url).to eq("https://cdn.snapapi.pics/abc.png")
    end

    it "accepts html input" do
      stub_post("/v1/screenshot", response_body: fake_png, content_type: "image/png")
      result = client.screenshot(html: "<h1>Hello</h1>")
      expect(result).to be_a(String)
    end
  end

  describe "#screenshot_to_file" do
    it "writes PNG bytes to disk and returns byte count" do
      stub_post("/v1/screenshot", response_body: fake_png, content_type: "image/png")
      tmpfile = Tempfile.new(["snap_test", ".png"])
      begin
        client.screenshot_to_file("https://example.com", tmpfile.path)
        expect(File.size(tmpfile.path)).to be > 0
        expect(File.binread(tmpfile.path).b).to start_with("\x89PNG".b)
      ensure
        tmpfile.close
        tmpfile.unlink
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PDF
  # ---------------------------------------------------------------------------

  describe "#pdf" do
    it "returns PDF bytes" do
      stub_post("/v1/screenshot", response_body: "%PDF-1.4 fake", content_type: "application/pdf")
      result = client.pdf(url: "https://example.com")
      expect(result).to include("%PDF")
    end

    it "raises ArgumentError when neither url nor html provided" do
      expect { client.pdf }.to raise_error(ArgumentError, /url or html/)
    end

    it "sends pageSize and landscape in payload" do
      stub_post("/v1/screenshot", response_body: "%PDF-1.4", content_type: "application/pdf")
      client.pdf(url: "https://example.com", page_size: "letter", landscape: true)
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/screenshot")
        .with { |req|
          body = JSON.parse(req.body)
          body["pageSize"] == "letter" && body["landscape"] == true
        }
    end
  end

  describe "#generate_pdf" do
    it "is an alias for #pdf" do
      stub_post("/v1/screenshot", response_body: "%PDF-1.4", content_type: "application/pdf")
      result = client.generate_pdf(url: "https://example.com")
      expect(result).to include("%PDF")
    end
  end

  # ---------------------------------------------------------------------------
  # Scrape
  # ---------------------------------------------------------------------------

  describe "#scrape" do
    it "returns a ScrapeResult" do
      stub_post("/v1/scrape", response_body: { results: [{ data: "text content", url: "https://example.com" }] })
      result = client.scrape(url: "https://example.com")
      expect(result).to be_a(SnapAPI::ScrapeResult)
      expect(result.results).to be_an(Array)
      expect(result.results.first["data"]).to eq("text content")
    end
  end

  # ---------------------------------------------------------------------------
  # Extract
  # ---------------------------------------------------------------------------

  describe "#extract" do
    let(:extract_response) { { content: "# Example\n\nHello world", type: "markdown", url: "https://example.com" } }

    it "returns an ExtractResult" do
      stub_post("/v1/extract", response_body: extract_response)
      result = client.extract(url: "https://example.com")
      expect(result).to be_a(SnapAPI::ExtractResult)
      expect(result.content).to eq("# Example\n\nHello world")
    end

    it "sends correct type in payload" do
      stub_post("/v1/extract", response_body: extract_response)
      client.extract(url: "https://example.com", type: "article")
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/extract")
        .with { |req| JSON.parse(req.body)["type"] == "article" }
    end
  end

  describe "#extract_markdown" do
    it "calls extract with type=markdown" do
      stub_post("/v1/extract", response_body: { content: "**bold**", type: "markdown" })
      result = client.extract_markdown("https://example.com")
      expect(result).to be_a(SnapAPI::ExtractResult)
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/extract")
        .with { |req| JSON.parse(req.body)["type"] == "markdown" }
    end
  end

  describe "#extract_article" do
    it "calls extract with type=article" do
      stub_post("/v1/extract", response_body: { content: "article text", type: "article" })
      client.extract_article("https://example.com")
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/extract")
        .with { |req| JSON.parse(req.body)["type"] == "article" }
    end
  end

  describe "#extract_text" do
    it "calls extract with type=text" do
      stub_post("/v1/extract", response_body: { content: "plain text", type: "text" })
      client.extract_text("https://example.com")
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/extract")
        .with { |req| JSON.parse(req.body)["type"] == "text" }
    end
  end

  describe "#extract_links" do
    it "calls extract with type=links" do
      stub_post("/v1/extract", response_body: { content: ["https://a.com"], type: "links" })
      client.extract_links("https://example.com")
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/extract")
        .with { |req| JSON.parse(req.body)["type"] == "links" }
    end
  end

  describe "#extract_images" do
    it "calls extract with type=images" do
      stub_post("/v1/extract", response_body: { content: ["https://img.example.com/a.jpg"], type: "images" })
      client.extract_images("https://example.com")
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/extract")
        .with { |req| JSON.parse(req.body)["type"] == "images" }
    end
  end

  describe "#extract_metadata" do
    it "calls extract with type=metadata" do
      stub_post("/v1/extract", response_body: { content: { title: "Example" }, type: "metadata" })
      client.extract_metadata("https://example.com")
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/extract")
        .with { |req| JSON.parse(req.body)["type"] == "metadata" }
    end
  end

  # ---------------------------------------------------------------------------
  # Video
  # ---------------------------------------------------------------------------

  describe "#video" do
    it "returns raw video bytes" do
      fake_mp4 = "\x00\x00\x00\x20ftyp"  # ftyp box marker
      stub_post("/v1/video", response_body: fake_mp4, content_type: "video/mp4")
      result = client.video(url: "https://example.com")
      expect(result).to be_a(String)
    end
  end

  # ---------------------------------------------------------------------------
  # OG Image
  # ---------------------------------------------------------------------------

  describe "#og_image" do
    it "returns raw image bytes" do
      stub_post("/v1/screenshot", response_body: fake_png, content_type: "image/png")
      result = client.og_image(url: "https://example.com")
      expect(result).to start_with("\x89PNG")
    end

    it "sends width=1200 and height=630 by default" do
      stub_post("/v1/screenshot", response_body: fake_png, content_type: "image/png")
      client.og_image(url: "https://example.com")
      expect(WebMock).to have_requested(:post, "https://api.snapapi.pics/v1/screenshot")
        .with { |req|
          body = JSON.parse(req.body)
          body["width"] == 1200 && body["height"] == 630
        }
    end
  end

  describe "#generate_og_image" do
    it "is an alias for #og_image" do
      stub_post("/v1/screenshot", response_body: fake_png, content_type: "image/png")
      result = client.generate_og_image(url: "https://example.com")
      expect(result).to start_with("\x89PNG")
    end
  end

  # ---------------------------------------------------------------------------
  # Analyze
  # ---------------------------------------------------------------------------

  describe "#analyze" do
    it "returns an AnalyzeResult" do
      stub_post("/v1/analyze", response_body: {
        result: "This page is about examples.",
        model: "gpt-4o",
        provider: "openai"
      })
      result = client.analyze(url: "https://example.com", prompt: "Summarize this page.")
      expect(result).to be_a(SnapAPI::AnalyzeResult)
      expect(result.result).to eq("This page is about examples.")
      expect(result.model).to eq("gpt-4o")
    end
  end

  # ---------------------------------------------------------------------------
  # Usage / Quota / Ping
  # ---------------------------------------------------------------------------

  describe "#get_usage" do
    it "returns a UsageResult" do
      stub_get("/v1/usage", response_body: { used: 42, limit: 1000, remaining: 958, resetAt: "2026-04-01T00:00:00Z" })
      result = client.get_usage
      expect(result).to be_a(SnapAPI::UsageResult)
      expect(result.used).to eq(42)
      expect(result.remaining).to eq(958)
    end
  end

  describe "#quota" do
    it "is an alias for get_usage" do
      stub_get("/v1/usage", response_body: { used: 10, limit: 1000, remaining: 990 })
      expect(client.quota).to be_a(SnapAPI::UsageResult)
    end
  end

  describe "#ping" do
    it "returns a hash with status ok" do
      stub_get("/v1/ping", response_body: { status: "ok", timestamp: 1_710_000_000_000 })
      result = client.ping
      expect(result).to be_a(Hash)
      expect(result["status"]).to eq("ok")
    end
  end

  # ---------------------------------------------------------------------------
  # Error handling
  # ---------------------------------------------------------------------------

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_post("/v1/screenshot",
                response_body: { message: "Invalid API key", error: "UNAUTHORIZED" },
                status: 401)
      expect { client.screenshot(url: "https://example.com") }
        .to raise_error(SnapAPI::AuthenticationError) do |e|
          expect(e.status_code).to eq(401)
        end
    end

    it "raises QuotaExceededError on 402" do
      stub_post("/v1/screenshot",
                response_body: { message: "Quota exceeded", error: "QUOTA_EXCEEDED" },
                status: 402)
      expect { client.screenshot(url: "https://example.com") }
        .to raise_error(SnapAPI::QuotaExceededError)
    end

    it "raises ValidationError on 422" do
      stub_post("/v1/screenshot",
                response_body: { message: "url is required", error: "VALIDATION_ERROR" },
                status: 422)
      # Bypass local validation by going directly to http client
      expect {
        client.instance_variable_get(:@http).post("/v1/screenshot", { format: "png" })
      }.to raise_error(SnapAPI::ValidationError)
    end

    it "raises RateLimitError on 429" do
      stub_request(:post, "https://api.snapapi.pics/v1/screenshot")
        .to_return(
          status: 429,
          body: JSON.generate({ message: "Too many requests", error: "RATE_LIMITED" }),
          headers: { "Content-Type" => "application/json", "Retry-After" => "2" }
        )
        .times(4)  # initial + 3 retries
      expect { client.screenshot(url: "https://example.com") }
        .to raise_error(SnapAPI::RateLimitError) do |e|
          expect(e.retry_after).to eq(2.0)
        end
    end

    it "raises SnapAPI::Error on 500" do
      stub_request(:post, "https://api.snapapi.pics/v1/screenshot")
        .to_return(
          status: 500,
          body: JSON.generate({ message: "Internal server error" }),
          headers: { "Content-Type" => "application/json" }
        )
        .times(4)  # initial + 3 retries
      expect { client.screenshot(url: "https://example.com") }
        .to raise_error(SnapAPI::Error) do |e|
          expect(e.status_code).to eq(500)
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Error class hierarchy
  # ---------------------------------------------------------------------------

  describe "error hierarchy" do
    it "AuthenticationError is a SnapAPI::Error" do
      expect(SnapAPI::AuthenticationError.new).to be_a(SnapAPI::Error)
    end

    it "RateLimitError is a SnapAPI::Error" do
      expect(SnapAPI::RateLimitError.new).to be_a(SnapAPI::Error)
    end

    it "QuotaExceededError is a SnapAPI::Error" do
      expect(SnapAPI::QuotaExceededError.new).to be_a(SnapAPI::Error)
    end

    it "ValidationError is a SnapAPI::Error" do
      expect(SnapAPI::ValidationError.new).to be_a(SnapAPI::Error)
    end

    it "TimeoutError is a SnapAPI::Error" do
      expect(SnapAPI::TimeoutError.new).to be_a(SnapAPI::Error)
    end

    it "NetworkError is a SnapAPI::Error" do
      expect(SnapAPI::NetworkError.new("fail")).to be_a(SnapAPI::Error)
    end

    it "all SnapAPI errors are StandardError" do
      expect(SnapAPI::Error.new).to be_a(StandardError)
    end
  end

  # ---------------------------------------------------------------------------
  # Request headers
  # ---------------------------------------------------------------------------

  describe "request headers" do
    it "sends X-Api-Key and Authorization headers" do
      stub_get("/v1/ping", response_body: { status: "ok" })
      client.ping
      expect(WebMock).to have_requested(:get, "https://api.snapapi.pics/v1/ping")
        .with(headers: {
          "X-Api-Key" => api_key,
          "Authorization" => "Bearer #{api_key}"
        })
    end

    it "sends correct User-Agent" do
      stub_get("/v1/ping", response_body: { status: "ok" })
      client.ping
      expect(WebMock).to have_requested(:get, "https://api.snapapi.pics/v1/ping")
        .with(headers: { "User-Agent" => "snapapi-ruby/#{SnapAPI::VERSION}" })
    end
  end
end
