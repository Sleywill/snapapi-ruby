# Changelog

All notable changes to the SnapAPI Ruby gem are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [2.1.0] - 2026-03-23

### Changed

- **HTTP client switched to Faraday** with retry middleware for more robust networking.
- **Minimum Ruby version raised to 3.0+** (was 2.6).
- Version reset to 2.1.0 to align with SDK versioning across all languages.

### Added

- **Configuration block** -- `SnapAPI.configure { |c| c.api_key = "..." }` for setting defaults once.
- `SnapAPI.reset_configuration!` for test isolation.
- `generate_pdf` method alias for `pdf`.
- `generate_og_image` method alias for `og_image`.
- YARD documentation on all public methods.
- CI now tests Ruby 3.0, 3.1, 3.2, and 3.3.

### Fixed

- Client now falls back to `SnapAPI.configuration.api_key` when not passed directly.
- Direct `api_key` parameter takes precedence over configuration block.

## [1.0.0] - 2026-03-17

### Added

- Initial public release of the official SnapAPI Ruby gem.
- `SnapAPI::Client` -- synchronous client backed by Ruby's built-in `Net::HTTP`.
- **Screenshot** -- `screenshot`, `screenshot_to_file`
- **PDF** -- `pdf`, `pdf_to_file`
- **Scrape** -- `scrape`
- **Extract** -- `extract` plus six convenience methods:
  `extract_markdown`, `extract_article`, `extract_text`,
  `extract_links`, `extract_images`, `extract_metadata`
- **Video** -- `video`
- **OG Image** -- `og_image`
- **Analyze** -- `analyze` (BYOK -- bring your own LLM API key)
- **Usage** -- `get_usage`, `quota`
- **Ping** -- `ping`
- Typed exception hierarchy:
  `SnapAPI::Error`, `AuthenticationError`, `RateLimitError`,
  `QuotaExceededError`, `ValidationError`, `TimeoutError`, `NetworkError`
- Automatic retry with exponential backoff on 429 and 5xx responses (default: 3 retries).
- `Retry-After` header support for rate-limit retries.
- Response model classes: `ScreenshotResult`, `ScrapeResult`, `ExtractResult`,
  `AnalyzeResult`, `VideoResult`, `UsageResult`, `DeleteResult`, `StorageFile`.
- RSpec test suite with WebMock stubs (30+ examples).
- MIT license.
