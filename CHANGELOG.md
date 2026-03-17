# Changelog

All notable changes to the SnapAPI Ruby gem are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [3.1.0] - 2026-03-17

### Added

- Initial public release of the official SnapAPI Ruby gem.
- `SnapAPI::Client` — synchronous client backed by Ruby's built-in `Net::HTTP`.
- **Screenshot** — `screenshot`, `screenshot_to_file`
- **PDF** — `pdf`, `pdf_to_file`
- **Scrape** — `scrape`
- **Extract** — `extract` plus six convenience methods:
  `extract_markdown`, `extract_article`, `extract_text`,
  `extract_links`, `extract_images`, `extract_metadata`
- **Video** — `video`
- **OG Image** — `og_image`
- **Analyze** — `analyze` (BYOK — bring your own LLM API key)
- **Usage** — `get_usage`, `quota`
- **Ping** — `ping`
- Typed exception hierarchy:
  `SnapAPI::Error`, `AuthenticationError`, `RateLimitError`,
  `QuotaExceededError`, `ValidationError`, `TimeoutError`, `NetworkError`
- Automatic retry with exponential backoff on 429 and 5xx responses (default: 3 retries).
- `Retry-After` header support for rate-limit retries.
- Response model classes: `ScreenshotResult`, `ScrapeResult`, `ExtractResult`,
  `AnalyzeResult`, `VideoResult`, `UsageResult`, `DeleteResult`, `StorageFile`.
- Zero runtime dependencies — uses only Ruby standard library (`net/http`, `json`, `uri`).
- Ruby 2.7+ compatibility.
- RSpec test suite with WebMock stubs (30+ examples).
- MIT license.
