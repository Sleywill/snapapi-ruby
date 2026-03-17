# frozen_string_literal: true

# Convenience alias — the HTTP transport layer lives in http_client.rb.
# This file is provided so that consumers who do
#   require "snapapi/http"
# get the HttpClient class.
require_relative "http_client"
