# frozen_string_literal: true

# SnapAPI Ruby SDK — Official client for https://snapapi.pics
#
# == Usage
#
#   require "snapapi"
#
#   client = SnapAPI::Client.new(api_key: "sk_live_...")
#   png = client.screenshot(url: "https://example.com")
#   File.binwrite("screenshot.png", png)
#
# @see https://snapapi.pics/docs
# @see SnapAPI::Client
module SnapAPI
end

require_relative "snapapi/version"
require_relative "snapapi/errors"
require_relative "snapapi/models"
require_relative "snapapi/http_client"
require_relative "snapapi/client"
