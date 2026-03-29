# SnapAPI Ruby SDK

Official Ruby gem for [SnapAPI](https://snapapi.pics) — the lightning-fast screenshot, scrape, extract, PDF, video, and AI-analyze API.

[![Gem Version](https://img.shields.io/gem/v/snapapi?label=rubygems&color=cc3429)](https://rubygems.org/gems/snapapi)
[![Gem Downloads](https://img.shields.io/gem/dt/snapapi?label=downloads&color=cc3429)](https://rubygems.org/gems/snapapi)
[![CI](https://github.com/Sleywill/snapapi-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/Sleywill/snapapi-ruby/actions)
[![Ruby 3.0+](https://img.shields.io/badge/Ruby-3.0%2B-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

## Installation

Add to your `Gemfile`:

```ruby
gem "snapapi"
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install snapapi
```

## Quick Start

```ruby
require "snapapi"

client = SnapAPI::Client.new(api_key: "sk_live_...")

# Take a screenshot
png = client.screenshot(url: "https://example.com")
File.binwrite("screenshot.png", png)

# Save directly to a file
client.screenshot_to_file("https://example.com", "screenshot.png")
```

## Features

- **Faraday HTTP client** with retry middleware for robust networking
- **Automatic retries** with exponential backoff on 429 / 5xx responses
- **Rate limit handling** with `Retry-After` header support
- **Configuration block** -- set defaults once via `SnapAPI.configure`
- **Typed response objects** -- structured, IDE-friendly results
- **Custom exception hierarchy** per error category
- **All endpoints** -- screenshot, scrape, extract, PDF, video, OG image, analyze
- **YARD documentation** on all public methods
- **Ruby 3.0+**

## Configuration

### Configuration Block (recommended)

```ruby
SnapAPI.configure do |config|
  config.api_key     = "sk_live_..."
  config.base_url    = "https://api.snapapi.pics"  # Default
  config.timeout     = 60                           # Seconds (default: 60)
  config.max_retries = 3                            # Auto-retry on 429 / 5xx (default: 3)
  config.retry_delay = 0.5                          # Initial backoff seconds (doubles each retry)
end

client = SnapAPI::Client.new
```

### Direct Configuration

```ruby
client = SnapAPI::Client.new(
  api_key:     "sk_live_...",
  base_url:    "https://api.snapapi.pics",  # Default
  timeout:     60,                           # Seconds (default: 60)
  max_retries: 3,                            # Auto-retry on 429 / 5xx (default: 3)
  retry_delay: 0.5,                          # Initial backoff seconds (doubles each retry)
)
```

## API Reference

### Screenshot

Capture a screenshot of any URL, raw HTML, or Markdown.

```ruby
# Basic PNG screenshot
png = client.screenshot(url: "https://example.com")

# Full-page dark-mode WebP with ad blocking
webp = client.screenshot(
  url:              "https://github.com",
  format:           "webp",
  full_page:        true,
  dark_mode:        true,
  block_ads:        true,
  block_trackers:   true,
  width:            1440,
  height:           900,
)

# Render raw HTML
png = client.screenshot(html: "<h1 style='color:red'>Hello!</h1>")

# Capture only a specific element
png = client.screenshot(
  url:      "https://example.com",
  selector: "#main-content",
)

# Save to file directly
client.screenshot_to_file("https://example.com", "./output/screenshot.png")

# With custom device emulation
png = client.screenshot(
  url:                  "https://example.com",
  device:               "iPhone 14",
  device_scale_factor:  2.0,
  is_mobile:            true,
  has_touch:            true,
)

# With cookies and HTTP auth
png = client.screenshot(
  url:         "https://example.com/protected",
  http_auth:   { username: "user", password: "pass" },
  cookies:     [{ name: "session", value: "abc123", domain: "example.com" }],
)

# Store result in SnapAPI cloud
result = client.screenshot(
  url:     "https://example.com",
  storage: { destination: "snapapi" },
)
puts result.url  # Public CDN URL
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | String | URL to capture (required unless `html`/`markdown` given) |
| `html` | String | Raw HTML string to render |
| `markdown` | String | Markdown string to render |
| `format` | String | `"png"`, `"jpeg"`, `"webp"`, `"avif"`, or `"pdf"` (default: `"png"`) |
| `quality` | Integer | Image quality 1-100 (JPEG/WebP only) |
| `device` | String | Named device preset (overrides width/height) |
| `width` | Integer | Viewport width in pixels (default: 1280) |
| `height` | Integer | Viewport height in pixels (default: 800) |
| `device_scale_factor` | Float | Device pixel ratio 1-3 (default: 1.0) |
| `is_mobile` | Boolean | Emulate mobile device |
| `has_touch` | Boolean | Enable touch events |
| `full_page` | Boolean | Capture full scrollable page |
| `full_page_scroll_delay` | Integer | Delay between scroll steps (ms) |
| `full_page_max_height` | Integer | Maximum height for full-page capture (px) |
| `selector` | String | CSS selector — capture only that element |
| `delay` | Integer | Extra delay before capture in ms (0-30000) |
| `timeout` | Integer | Navigation timeout in ms |
| `wait_until` | String | Navigation event to wait for |
| `wait_for_selector` | String | CSS selector to wait for |
| `dark_mode` | Boolean | Emulate dark colour scheme |
| `reduced_motion` | Boolean | Reduce CSS animations |
| `css` | String | Custom CSS to inject |
| `javascript` | String | JavaScript to run before capture |
| `hide_selectors` | Array\<String\> | CSS selectors to hide |
| `click_selector` | String | CSS selector to click before capture |
| `block_ads` | Boolean | Block ad networks |
| `block_trackers` | Boolean | Block tracking scripts |
| `block_cookie_banners` | Boolean | Block cookie consent banners |
| `block_chat_widgets` | Boolean | Block chat widgets |
| `user_agent` | String | Custom User-Agent string |
| `extra_headers` | Hash | Extra HTTP request headers |
| `cookies` | Array\<Hash\> | Cookies to inject |
| `http_auth` | Hash | HTTP Basic Auth credentials |
| `proxy` | Hash | Custom proxy configuration |
| `premium_proxy` | Boolean | Use SnapAPI rotating proxy |
| `geolocation` | Hash | GPS coordinates to emulate |
| `timezone` | String | IANA timezone string |
| `storage` | Hash | Store result in cloud |
| `webhook_url` | String | Deliver result to webhook URL asynchronously |

**Returns:** Raw `String` bytes for binary responses. `SnapAPI::ScreenshotResult` when `storage` or `webhook_url` is set.

---

### PDF

Generate a PDF from a URL or HTML string.

```ruby
# Basic PDF
pdf_bytes = client.pdf(url: "https://example.com")
File.binwrite("output.pdf", pdf_bytes)

# Save directly to file
client.pdf_to_file("https://example.com", "./output.pdf")

# A3 landscape with margins
pdf_bytes = client.pdf(
  url:       "https://example.com",
  page_size: "a3",
  landscape: true,
  margins:   { top: "1cm", right: "1cm", bottom: "1cm", left: "1cm" },
)

# From HTML
pdf_bytes = client.pdf(
  html:       "<h1>Invoice #1234</h1><p>Amount: $99.00</p>",
  page_size:  "letter",
)

# With custom header and footer
pdf_bytes = client.pdf(
  url:                     "https://example.com",
  display_header_footer:   true,
  header_template:         "<div style='font-size:10px'>Report</div>",
  footer_template:         "<div style='font-size:10px'>Page <span class='pageNumber'></span></div>",
)
```

**Returns:** Raw PDF bytes (`String`).

---

### Scrape

Scrape text, HTML, or links from one or more pages.

```ruby
# Scrape text content
result = client.scrape(url: "https://example.com")
result.results.each { |page| puts page["data"] }

# Scrape links
result = client.scrape(url: "https://example.com", type: "links")

# Scrape multiple pages
result = client.scrape(url: "https://example.com", pages: 3)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | String | URL to scrape (required) |
| `type` | String | `"text"`, `"html"`, or `"links"` (default: `"text"`) |
| `pages` | Integer | Number of pages to scrape 1-10 (default: 1) |
| `wait_ms` | Integer | Wait time after page load (ms) |
| `proxy` | String | Proxy URL |
| `premium_proxy` | Boolean | Use SnapAPI rotating proxy |
| `block_resources` | Boolean | Block images/fonts/media |
| `locale` | String | Browser locale, e.g. `"en-US"` |

**Returns:** `SnapAPI::ScrapeResult` with `.results` array.

---

### Extract

Extract structured content from a web page for LLM pipelines.

```ruby
# Extract as Markdown (default)
result = client.extract(url: "https://example.com")
puts result.content

# Extract main article
result = client.extract_article("https://example.com/blog/post")

# Extract plain text
result = client.extract_text("https://example.com")

# Extract all links
result = client.extract_links("https://example.com")

# Extract all images
result = client.extract_images("https://example.com")

# Extract page metadata
result = client.extract_metadata("https://example.com")
puts result.content["title"]
puts result.content["description"]

# Scoped extraction with CSS selector
result = client.extract(
  url:      "https://example.com",
  type:     "markdown",
  selector: "#article-content",
)

# Truncate output
result = client.extract(
  url:        "https://example.com",
  max_length: 5000,
  clean_output: true,
)
```

**Returns:** `SnapAPI::ExtractResult` with `.content`, `.url`, `.type`, `.metadata`.

---

### Video

Record a video of a live webpage.

```ruby
# Basic MP4 recording
video_bytes = client.video(url: "https://example.com")
File.binwrite("recording.mp4", video_bytes)

# With scroll animation
video_bytes = client.video(
  url:       "https://example.com",
  format:    "mp4",
  duration:  10,
  scrolling: true,
  width:     1280,
  height:    720,
)

# Dark mode GIF
gif_bytes = client.video(
  url:       "https://example.com",
  format:    "gif",
  duration:  5,
  dark_mode: true,
)
```

**Returns:** Raw video bytes (`String`).

---

### OG Image

Generate an Open Graph social preview image.

```ruby
og_bytes = client.og_image(url: "https://example.com")
File.binwrite("og.png", og_bytes)

# Custom dimensions
og_bytes = client.og_image(
  url:    "https://example.com",
  format: "jpeg",
  width:  1200,
  height: 628,
)
```

**Returns:** Raw image bytes (`String`).

---

### Analyze (LLM)

Analyze a web page with an LLM using your own API key (BYOK).

```ruby
# Analyze with OpenAI
result = client.analyze(
  url:      "https://example.com",
  prompt:   "Summarize this page in 3 bullet points.",
  provider: "openai",
  api_key:  "sk-...",
)
puts result.result

# Structured output with JSON schema
result = client.analyze(
  url:     "https://example.com/product",
  prompt:  "Extract product information",
  provider: "openai",
  api_key:  "sk-...",
  json_schema: {
    type: "object",
    properties: {
      name:  { type: "string" },
      price: { type: "number" },
    }
  },
)
```

**Returns:** `SnapAPI::AnalyzeResult` with `.result`, `.model`, `.provider`.

---

### Usage & Quota

```ruby
usage = client.get_usage
puts "#{usage.used} / #{usage.limit} calls used"
puts "Resets at: #{usage.reset_at}"

# quota is an alias
usage = client.quota
```

**Returns:** `SnapAPI::UsageResult` with `.used`, `.limit`, `.remaining`, `.reset_at`.

---

### Health Check

```ruby
result = client.ping
puts result["status"]  # => "ok"
```

---

## Error Handling

All errors inherit from `SnapAPI::Error < StandardError`.

```ruby
begin
  png = client.screenshot(url: "https://example.com")
rescue SnapAPI::AuthenticationError => e
  puts "Bad API key: #{e.message}"
rescue SnapAPI::RateLimitError => e
  puts "Rate limited. Retry after: #{e.retry_after}s"
  sleep(e.retry_after)
  retry
rescue SnapAPI::QuotaExceededError => e
  puts "Quota exhausted. Upgrade your plan."
rescue SnapAPI::ValidationError => e
  puts "Invalid params: #{e.message}"
  puts e.fields.inspect
rescue SnapAPI::TimeoutError
  puts "Request timed out."
rescue SnapAPI::NetworkError => e
  puts "Network failure: #{e.message}"
rescue SnapAPI::Error => e
  puts "API error #{e.status_code}: #{e.message} (#{e.code})"
end
```

| Exception | HTTP Status | Description |
|-----------|-------------|-------------|
| `SnapAPI::AuthenticationError` | 401 / 403 | Invalid or missing API key |
| `SnapAPI::RateLimitError` | 429 | Too many requests (auto-retried) |
| `SnapAPI::QuotaExceededError` | 402 | Monthly quota exhausted |
| `SnapAPI::ValidationError` | 422 | Invalid request parameters |
| `SnapAPI::TimeoutError` | — | Request timed out |
| `SnapAPI::NetworkError` | — | DNS / connection failure |
| `SnapAPI::Error` | any | Base class for all SnapAPI errors |

---

## Retry Logic

The SDK automatically retries on:
- **HTTP 429** (rate limited) — uses the `Retry-After` response header.
- **HTTP 5xx** (server errors) — exponential backoff.
- **Network timeouts** — exponential backoff.

Default: 3 retries, initial delay 0.5s (doubles each attempt, capped at 30s).

```ruby
client = SnapAPI::Client.new(
  api_key:     "sk_live_...",
  max_retries: 5,     # Up to 5 retries
  retry_delay: 1.0,   # Start at 1s, then 2s, 4s, 8s, 16s
)
```

To disable retries:

```ruby
client = SnapAPI::Client.new(api_key: "sk_live_...", max_retries: 0)
```

---

## Response Objects

All JSON responses are wrapped in typed response objects. Every attribute is accessible as a method:

```ruby
result = client.extract_metadata("https://example.com")
result.content      # => Hash or String
result.url          # => "https://example.com"
result.type         # => "metadata"
result.to_h         # => Raw Hash
result.raw          # => Raw Hash

usage = client.get_usage
usage.used          # => 42
usage.limit         # => 1000
usage.remaining     # => 958
```

---

## Development

```bash
git clone https://github.com/Sleywill/snapapi-ruby
cd snapapi-ruby
bundle install
bundle exec rspec
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) before submitting a PR.

Found a bug? [Open an issue](https://github.com/Sleywill/snapapi-ruby/issues/new?template=bug_report.md).
Have an idea? [Request a feature](https://github.com/Sleywill/snapapi-ruby/issues/new?template=feature_request.md).

## License

MIT — see [LICENSE](LICENSE).

## Links

- [SnapAPI Website](https://snapapi.pics)
- [API Documentation](https://snapapi.pics/docs)
- [RubyGems](https://rubygems.org/gems/snapapi)
- [GitHub Repository](https://github.com/Sleywill/snapapi-ruby)
- [Changelog](./CHANGELOG.md)
- [Report Issues](https://github.com/Sleywill/snapapi-ruby/issues)
