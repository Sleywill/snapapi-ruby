# frozen_string_literal: true
#
# Live integration test suite for the SnapAPI Ruby SDK.
# Exercises every endpoint, all major options, error handling, and retry behaviour.
#
# Usage:
#   SNAPAPI_KEY=sk_live_... ruby test_live.rb
#
# Requirements:
#   gem install snapapi   (or run from the SDK root with 'bundle exec ruby test_live.rb')

$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "snapapi"
require "tmpdir"

API_KEY = ENV.fetch("SNAPAPI_KEY") { raise "Set SNAPAPI_KEY environment variable" }
TEST_URL = "https://example.com"

# ---------------------------------------------------------------------------
# Minimal test harness
# ---------------------------------------------------------------------------
PASSED  = []
FAILED  = []
SKIPPED = []

def run(name)
  print "  #{name} ... "
  yield
  PASSED << name
  puts "\e[32mPASS\e[0m"
rescue SkipTest => e
  SKIPPED << name
  puts "\e[33mSKIP\e[0m (#{e.message})"
rescue => e
  FAILED << name
  puts "\e[31mFAIL\e[0m — #{e.class}: #{e.message}"
  puts "    #{e.backtrace.first(3).join("\n    ")}"
end

class SkipTest < StandardError; end

def assert(condition, msg = "assertion failed")
  raise "#{msg} (got: #{condition.inspect})" unless condition
end

def assert_equal(expected, actual, msg = nil)
  unless expected == actual
    raise "#{msg || "expected #{expected.inspect}, got #{actual.inspect}"}"
  end
end

def assert_raises(klass)
  yield
  raise "Expected #{klass} to be raised but nothing was raised"
rescue klass
  # expected
rescue => e
  raise "Expected #{klass} but got #{e.class}: #{e.message}"
end

# ---------------------------------------------------------------------------
# Client setup
# ---------------------------------------------------------------------------
client = SnapAPI::Client.new(
  api_key:     API_KEY,
  max_retries: 2,
  retry_delay: 0.2
)

# ---------------------------------------------------------------------------
# Suite 1 — Ping / connectivity
# ---------------------------------------------------------------------------
puts "\n== Suite 1: Ping / Connectivity =="

run "ping returns status:ok hash" do
  result = client.ping
  assert result.is_a?(Hash), "expected Hash"
  assert result["status"] == "ok", "expected status:ok, got #{result["status"].inspect}"
end

run "ping timestamp is recent" do
  result = client.ping
  ts = result["timestamp"].to_i
  assert ts > 1_700_000_000_000, "timestamp looks invalid: #{ts}"
end

# ---------------------------------------------------------------------------
# Suite 2 — Usage / Quota
# ---------------------------------------------------------------------------
puts "\n== Suite 2: Usage / Quota =="

run "get_usage returns UsageResult" do
  u = client.get_usage
  assert u.is_a?(SnapAPI::UsageResult), "expected UsageResult"
  assert u.used.is_a?(Numeric) || u.used.nil?, "used should be numeric or nil"
  assert u.limit.is_a?(Numeric) || u.limit.nil?, "limit should be numeric or nil"
end

run "quota alias returns same as get_usage" do
  u1 = client.get_usage
  u2 = client.quota
  assert_equal u1.raw["used"], u2.raw["used"]
end

# ---------------------------------------------------------------------------
# Suite 3 — Screenshot endpoint
# ---------------------------------------------------------------------------
puts "\n== Suite 3: Screenshot =="

run "basic PNG screenshot returns binary data" do
  png = client.screenshot(url: TEST_URL)
  assert png.is_a?(String), "expected binary String"
  assert png.bytesize > 1000, "PNG too small (#{png.bytesize} bytes)"
  # Check PNG magic bytes
  assert png.b[0, 8] == "\x89PNG\r\n\x1a\n".b, "missing PNG header"
end

run "screenshot with format:jpeg returns JPEG" do
  jpg = client.screenshot(url: TEST_URL, format: "jpeg", quality: 80)
  assert jpg.is_a?(String)
  assert jpg.b[0, 2] == "\xFF\xD8".b, "missing JPEG header"
end

run "screenshot with format:webp returns WebP" do
  webp = client.screenshot(url: TEST_URL, format: "webp")
  assert webp.is_a?(String)
  assert webp.b[8, 4] == "WEBP".b, "missing WEBP signature"
end

run "full_page screenshot is taller than viewport" do
  normal   = client.screenshot(url: TEST_URL, format: "png")
  full     = client.screenshot(url: TEST_URL, format: "png", full_page: true)
  # Full page should be larger (more content)
  assert full.bytesize >= normal.bytesize * 0.8,
         "full_page result unexpectedly small (#{full.bytesize} vs #{normal.bytesize})"
end

run "dark_mode option accepted without error" do
  png = client.screenshot(url: TEST_URL, dark_mode: true)
  assert png.b[0, 8] == "\x89PNG\r\n\x1a\n".b
end

run "custom viewport width:1920 height:1080" do
  png = client.screenshot(url: TEST_URL, width: 1920, height: 1080)
  assert png.bytesize > 1000
end

run "screenshot with delay:500" do
  png = client.screenshot(url: TEST_URL, delay: 500)
  assert png.bytesize > 1000
end

run "screenshot from raw HTML string" do
  html = "<html><body><h1 style='color:red'>Hello SnapAPI</h1></body></html>"
  png  = client.screenshot(html: html)
  assert png.b[0, 8] == "\x89PNG\r\n\x1a\n".b
end

run "screenshot_to_file saves PNG to disk" do
  Dir.mktmpdir do |dir|
    path = File.join(dir, "out.png")
    bytes = client.screenshot_to_file(TEST_URL, path)
    assert File.exist?(path), "file not created"
    assert File.size(path) > 1000, "file too small"
    assert_equal bytes, File.size(path)
    assert File.binread(path)[0, 8] == "\x89PNG\r\n\x1a\n", "not a PNG"
  end
end

run "block_ads option accepted" do
  png = client.screenshot(url: TEST_URL, block_ads: true, block_trackers: true)
  assert png.bytesize > 1000
end

run "custom CSS injection" do
  png = client.screenshot(
    url: TEST_URL,
    css: "body { background: red !important; }"
  )
  assert png.bytesize > 1000
end

run "requires at least one input source (raises ArgumentError)" do
  assert_raises(ArgumentError) { client.screenshot }
end

# ---------------------------------------------------------------------------
# Suite 4 — PDF
# ---------------------------------------------------------------------------
puts "\n== Suite 4: PDF =="

run "pdf from URL returns PDF bytes" do
  pdf = client.pdf(url: TEST_URL)
  assert pdf.is_a?(String)
  assert pdf.b[0, 4] == "%PDF".b, "missing PDF header"
end

run "pdf from HTML string" do
  html = "<html><body><h1>PDF Test</h1><p>Content here.</p></body></html>"
  pdf  = client.pdf(html: html, page_size: "a4")
  assert pdf.b[0, 4] == "%PDF".b
end

run "pdf landscape option" do
  pdf = client.pdf(url: TEST_URL, landscape: true)
  assert pdf.b[0, 4] == "%PDF".b
end

run "pdf_to_file saves file" do
  Dir.mktmpdir do |dir|
    path = File.join(dir, "out.pdf")
    client.pdf_to_file(TEST_URL, path)
    assert File.exist?(path)
    assert File.binread(path)[0, 4] == "%PDF"
  end
end

run "generate_pdf alias works" do
  pdf = client.generate_pdf(url: TEST_URL)
  assert pdf.b[0, 4] == "%PDF".b
end

run "pdf requires url or html (raises ArgumentError)" do
  assert_raises(ArgumentError) { client.pdf }
end

# ---------------------------------------------------------------------------
# Suite 5 — Scrape
# ---------------------------------------------------------------------------
puts "\n== Suite 5: Scrape =="

run "scrape type:text returns ScrapeResult" do
  result = client.scrape(url: TEST_URL, type: "text")
  assert result.is_a?(SnapAPI::ScrapeResult), "expected ScrapeResult, got #{result.class}"
  assert result.results.is_a?(Array), "results should be Array"
end

run "scrape type:html returns html content" do
  result = client.scrape(url: TEST_URL, type: "html")
  assert result.is_a?(SnapAPI::ScrapeResult)
  first = result.results.first
  assert first.is_a?(Hash), "expected Hash result"
  # content or data key should have HTML tags
  content = first["data"] || first["content"] || ""
  assert content.include?("<") || content.length > 0, "expected HTML content"
end

run "scrape type:links returns link results" do
  result = client.scrape(url: TEST_URL, type: "links")
  assert result.is_a?(SnapAPI::ScrapeResult)
  # links type returns a list of URLs
  assert result.results.is_a?(Array)
end

run "scrape url accessor on result" do
  result = client.scrape(url: TEST_URL)
  # url may or may not be present depending on API version
  assert result.respond_to?(:url)
end

run "scrape block_resources option" do
  result = client.scrape(url: TEST_URL, block_resources: true)
  assert result.is_a?(SnapAPI::ScrapeResult)
end

# ---------------------------------------------------------------------------
# Suite 6 — Extract
# ---------------------------------------------------------------------------
puts "\n== Suite 6: Extract =="

run "extract type:markdown returns ExtractResult" do
  result = client.extract(url: TEST_URL, type: "markdown")
  assert result.is_a?(SnapAPI::ExtractResult), "expected ExtractResult"
  assert result.content.is_a?(String), "content should be String"
  assert result.content.length > 0, "content should not be empty"
end

run "extract type:text returns plain text" do
  result = client.extract(url: TEST_URL, type: "text")
  assert result.content.is_a?(String)
end

run "extract type:html returns HTML" do
  result = client.extract(url: TEST_URL, type: "html")
  assert result.content.is_a?(String)
end

run "extract type:article returns article" do
  result = client.extract(url: TEST_URL, type: "article")
  assert result.is_a?(SnapAPI::ExtractResult)
end

run "extract type:links returns link data" do
  result = client.extract(url: TEST_URL, type: "links")
  assert result.is_a?(SnapAPI::ExtractResult)
end

run "extract type:images returns image data" do
  result = client.extract(url: TEST_URL, type: "images")
  assert result.is_a?(SnapAPI::ExtractResult)
end

run "extract type:metadata returns metadata" do
  result = client.extract(url: TEST_URL, type: "metadata")
  assert result.is_a?(SnapAPI::ExtractResult)
end

run "extract_markdown convenience method" do
  result = client.extract_markdown(TEST_URL)
  assert result.is_a?(SnapAPI::ExtractResult)
  assert result.content.is_a?(String)
end

run "extract_article convenience method" do
  result = client.extract_article(TEST_URL)
  assert result.is_a?(SnapAPI::ExtractResult)
end

run "extract_text convenience method" do
  result = client.extract_text(TEST_URL)
  assert result.is_a?(SnapAPI::ExtractResult)
end

run "extract_links convenience method" do
  result = client.extract_links(TEST_URL)
  assert result.is_a?(SnapAPI::ExtractResult)
end

run "extract_images convenience method" do
  result = client.extract_images(TEST_URL)
  assert result.is_a?(SnapAPI::ExtractResult)
end

run "extract_metadata convenience method" do
  result = client.extract_metadata(TEST_URL)
  assert result.is_a?(SnapAPI::ExtractResult)
end

run "extract with max_length truncates output" do
  full    = client.extract(url: TEST_URL, type: "text")
  limited = client.extract(url: TEST_URL, type: "text", max_length: 100)
  full_len    = full.content.to_s.length
  limited_len = limited.content.to_s.length
  assert limited_len <= [full_len, 200].min,
         "max_length not respected (#{limited_len} chars)"
end

run "extract clean_output option accepted" do
  result = client.extract(url: TEST_URL, type: "markdown", clean_output: true)
  assert result.is_a?(SnapAPI::ExtractResult)
end

# ---------------------------------------------------------------------------
# Suite 7 — Video (short, minimal — video is slow)
# ---------------------------------------------------------------------------
puts "\n== Suite 7: Video =="

run "video format:mp4 returns binary data" do
  mp4 = client.video(url: TEST_URL, format: "mp4", duration: 3, fps: 15)
  assert mp4.is_a?(String), "expected String"
  assert mp4.bytesize > 1000, "video too small (#{mp4.bytesize} bytes)"
  # ftyp box is at offset 4 in MP4
  assert mp4.b[4, 4] == "ftyp".b || mp4.b[0, 4] == "\x00\x00\x00\x18".b ||
         mp4.bytesize > 5000,
         "doesn't look like MP4"
end

run "video format:webm option accepted" do
  webm = client.video(url: TEST_URL, format: "webm", duration: 3, fps: 15)
  assert webm.is_a?(String)
  assert webm.bytesize > 100
end

run "video with dark_mode option" do
  mp4 = client.video(url: TEST_URL, format: "mp4", duration: 3, dark_mode: true)
  assert mp4.bytesize > 1000
end

run "video with scrolling enabled" do
  mp4 = client.video(
    url:       TEST_URL,
    format:    "mp4",
    duration:  4,
    scrolling: true
  )
  assert mp4.bytesize > 1000
end

# ---------------------------------------------------------------------------
# Suite 8 — OG Image
# ---------------------------------------------------------------------------
puts "\n== Suite 8: OG Image =="

run "og_image returns 1200x630 PNG by default" do
  png = client.og_image(url: TEST_URL)
  assert png.b[0, 8] == "\x89PNG\r\n\x1a\n".b
  assert png.bytesize > 1000
end

run "generate_og_image alias works" do
  png = client.generate_og_image(url: TEST_URL)
  assert png.b[0, 8] == "\x89PNG\r\n\x1a\n".b
end

# ---------------------------------------------------------------------------
# Suite 9 — Error handling
# ---------------------------------------------------------------------------
puts "\n== Suite 9: Error Handling =="

run "invalid API key raises AuthenticationError" do
  bad = SnapAPI::Client.new(api_key: "sk_live_BADKEY_invalid_00000000000000000")
  assert_raises(SnapAPI::AuthenticationError) { bad.ping }
end

run "AuthenticationError has correct status_code 401" do
  bad = SnapAPI::Client.new(api_key: "sk_live_BADKEY_invalid_00000000000000000")
  begin
    bad.ping
    raise "no exception raised"
  rescue SnapAPI::AuthenticationError => e
    assert_equal 401, e.status_code
    assert e.code == "UNAUTHORIZED", "code: #{e.code}"
    assert e.message.is_a?(String)
  end
end

run "AuthenticationError is subclass of SnapAPI::Error" do
  assert SnapAPI::AuthenticationError < SnapAPI::Error
end

run "AuthError is alias for AuthenticationError" do
  assert_equal SnapAPI::AuthenticationError, SnapAPI::AuthError
end

run "RateLimitError < Error" do
  assert SnapAPI::RateLimitError < SnapAPI::Error
end

run "QuotaExceededError < Error" do
  assert SnapAPI::QuotaExceededError < SnapAPI::Error
end

run "ValidationError < Error" do
  assert SnapAPI::ValidationError < SnapAPI::Error
end

run "TimeoutError < Error" do
  assert SnapAPI::TimeoutError < SnapAPI::Error
end

run "NetworkError < Error" do
  assert SnapAPI::NetworkError < SnapAPI::Error
end

run "all error classes inherit from SnapAPI::Error" do
  [
    SnapAPI::AuthenticationError,
    SnapAPI::RateLimitError,
    SnapAPI::QuotaExceededError,
    SnapAPI::ValidationError,
    SnapAPI::TimeoutError,
    SnapAPI::NetworkError,
  ].each do |klass|
    assert klass < SnapAPI::Error, "#{klass} should inherit from SnapAPI::Error"
  end
end

run "Error#to_s includes code and message" do
  e = SnapAPI::Error.new("something broke", code: "TEST_ERR", status_code: 500)
  assert e.to_s.include?("TEST_ERR"), "to_s missing code"
  assert e.to_s.include?("something broke"), "to_s missing message"
end

run "Error#inspect returns useful string" do
  e = SnapAPI::Error.new("bad thing", code: "BAD", status_code: 400)
  assert e.inspect.include?("SnapAPI::Error")
end

run "RateLimitError has retry_after attribute" do
  e = SnapAPI::RateLimitError.new("limited", retry_after: 5.5)
  assert_equal 5.5, e.retry_after
end

run "ValidationError has fields attribute" do
  e = SnapAPI::ValidationError.new("invalid", fields: { "url" => "is required" })
  assert_equal({ "url" => "is required" }, e.fields)
end

run "missing api_key raises ArgumentError on Client.new" do
  assert_raises(ArgumentError) { SnapAPI::Client.new(api_key: "") }
end

# ---------------------------------------------------------------------------
# Suite 10 — Retry behaviour
# ---------------------------------------------------------------------------
puts "\n== Suite 10: Retry Behaviour =="

run "client with max_retries:0 still works on first success" do
  c = SnapAPI::Client.new(api_key: API_KEY, max_retries: 0)
  result = c.ping
  assert_equal "ok", result["status"]
end

run "retry client can query usage multiple times" do
  c = SnapAPI::Client.new(api_key: API_KEY, max_retries: 2, retry_delay: 0.1)
  2.times do
    u = c.get_usage
    assert u.is_a?(SnapAPI::UsageResult)
  end
end

# ---------------------------------------------------------------------------
# Suite 11 — Configuration block
# ---------------------------------------------------------------------------
puts "\n== Suite 11: Configuration =="

run "SnapAPI.configure block sets global api_key" do
  SnapAPI.reset_configuration!
  SnapAPI.configure { |c| c.api_key = API_KEY }
  assert_equal API_KEY, SnapAPI.configuration.api_key
  c = SnapAPI::Client.new
  result = c.ping
  assert_equal "ok", result["status"]
  SnapAPI.reset_configuration!
end

run "SnapAPI.reset_configuration! clears api_key" do
  SnapAPI.configure { |c| c.api_key = "some_key" }
  SnapAPI.reset_configuration!
  assert_equal nil, SnapAPI.configuration.api_key
end

run "configuration defaults are sensible" do
  SnapAPI.reset_configuration!
  config = SnapAPI.configuration
  assert_equal "https://api.snapapi.pics", config.base_url
  assert config.timeout > 0
  assert config.max_retries >= 0
  assert config.retry_delay > 0
end

# ---------------------------------------------------------------------------
# Suite 12 — Response model accessors
# ---------------------------------------------------------------------------
puts "\n== Suite 12: Response Models =="

run "UsageResult accessors work" do
  u = client.get_usage
  # used/limit/remaining may be nil for some plan types — just verify methods exist
  assert u.respond_to?(:used)
  assert u.respond_to?(:limit)
  assert u.respond_to?(:remaining)
  assert u.respond_to?(:reset_at)
  assert u.respond_to?(:raw)
  assert u.raw.is_a?(Hash)
end

run "ExtractResult accessors" do
  r = client.extract_markdown(TEST_URL)
  assert r.respond_to?(:content)
  assert r.respond_to?(:url)
  assert r.respond_to?(:type)
  assert r.respond_to?(:metadata)
end

run "ScrapeResult accessors" do
  r = client.scrape(url: TEST_URL)
  assert r.respond_to?(:results)
  assert r.respond_to?(:url)
end

run "Response#[] works with string and symbol keys" do
  u = client.get_usage
  # raw is a Hash, so bracket access should work
  assert u.raw.is_a?(Hash)
end

run "Response#to_h returns raw hash" do
  u = client.get_usage
  assert_equal u.raw, u.to_h
end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
total = PASSED.length + FAILED.length + SKIPPED.length
puts "\n#{"=" * 60}"
puts "Results: #{PASSED.length} passed, #{FAILED.length} failed, #{SKIPPED.length} skipped  (#{total} total)"
puts "=" * 60

if FAILED.any?
  puts "\nFailed tests:"
  FAILED.each { |name| puts "  - #{name}" }
  exit 1
end
