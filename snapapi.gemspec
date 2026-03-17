# frozen_string_literal: true

require_relative "lib/snapapi/version"

Gem::Specification.new do |spec|
  spec.name    = "snapapi"
  spec.version = SnapAPI::VERSION
  spec.authors = ["SnapAPI Team"]
  spec.email   = ["sdk@snapapi.pics"]

  spec.summary     = "Official Ruby SDK for SnapAPI — screenshot, scrape, extract, PDF, video, and AI-analyze API"
  spec.description = <<~DESC
    SnapAPI lets you capture screenshots, generate PDFs, record videos, scrape structured
    data, extract content for LLMs, and run AI analysis on any web page — all via a simple
    REST API. This is the official Ruby gem with full type safety, automatic retries,
    and idiomatic Ruby patterns.
  DESC

  spec.homepage = "https://snapapi.pics"
  spec.license  = "MIT"

  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata = {
    "homepage_uri"    => spec.homepage,
    "source_code_uri" => "https://github.com/Sleywill/snapapi-ruby",
    "changelog_uri"   => "https://github.com/Sleywill/snapapi-ruby/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://rubydoc.info/gems/snapapi",
    "bug_tracker_uri" => "https://github.com/Sleywill/snapapi-ruby/issues",
  }

  # Only include the gem source files
  spec.files = Dir[
    "lib/**/*.rb",
    "LICENSE",
    "README.md",
    "CHANGELOG.md",
  ]

  spec.require_paths = ["lib"]

  # No runtime dependencies — uses only Ruby standard library (net/http, json, uri)

  spec.add_development_dependency "rspec",   "~> 3.12"
  spec.add_development_dependency "webmock", "~> 3.23"
  spec.add_development_dependency "rake",    "~> 13.0"
end
