# frozen_string_literal: true

# SnapAPI Ruby SDK -- Official client for https://snapapi.pics
#
# == Usage
#
#   require "snapapi"
#
#   client = SnapAPI::Client.new(api_key: "sk_live_...")
#   png = client.screenshot(url: "https://example.com")
#   File.binwrite("screenshot.png", png)
#
# == Configuration Block
#
#   SnapAPI.configure do |config|
#     config.api_key     = "sk_live_..."
#     config.base_url    = "https://api.snapapi.pics"
#     config.timeout     = 60
#     config.max_retries = 3
#     config.retry_delay = 0.5
#   end
#
#   client = SnapAPI::Client.new
#
# @see https://snapapi.pics/docs
# @see SnapAPI::Client
module SnapAPI
  # Global configuration for the SnapAPI SDK.
  # @see SnapAPI.configure
  class Configuration
    # @return [String, nil] Default API key.
    attr_accessor :api_key

    # @return [String] API base URL.
    attr_accessor :base_url

    # @return [Integer] Request timeout in seconds.
    attr_accessor :timeout

    # @return [Integer] Maximum retry attempts on 429/5xx.
    attr_accessor :max_retries

    # @return [Float] Initial backoff delay in seconds.
    attr_accessor :retry_delay

    def initialize
      @api_key     = nil
      @base_url    = "https://api.snapapi.pics"
      @timeout     = 60
      @max_retries = 3
      @retry_delay = 0.5
    end
  end

  class << self
    # @return [SnapAPI::Configuration] Current configuration.
    def configuration
      @configuration ||= Configuration.new
    end

    # Yields the global configuration to a block.
    #
    # @example
    #   SnapAPI.configure do |config|
    #     config.api_key = "sk_live_..."
    #   end
    #
    # @yield [SnapAPI::Configuration]
    def configure
      yield(configuration)
    end

    # Reset configuration to defaults. Useful in tests.
    # @return [SnapAPI::Configuration]
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

require_relative "snapapi/version"
require_relative "snapapi/errors"
require_relative "snapapi/models"
require_relative "snapapi/http_client"
require_relative "snapapi/client"
