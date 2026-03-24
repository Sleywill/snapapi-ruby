# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module SnapAPI
  # Internal HTTP transport layer using Faraday.
  # Handles serialisation, authentication, retry with exponential backoff,
  # and error mapping. Not part of the public API.
  class HttpClient # :nodoc:
    DEFAULT_BASE_URL    = "https://api.snapapi.pics"
    DEFAULT_TIMEOUT     = 60      # seconds
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_RETRY_DELAY = 0.5     # seconds
    MAX_RETRY_DELAY     = 30.0    # seconds

    def initialize(api_key:, base_url: DEFAULT_BASE_URL, timeout: DEFAULT_TIMEOUT,
                   max_retries: DEFAULT_MAX_RETRIES, retry_delay: DEFAULT_RETRY_DELAY)
      @api_key     = api_key
      @base_url    = base_url.chomp("/")
      @timeout     = timeout
      @max_retries = max_retries
      @retry_delay = retry_delay

      @conn = build_connection
    end

    # Perform a GET request.
    # @return [String, Hash] raw bytes for binary, Hash for JSON
    def get(path)
      request_with_retry(:get, path)
    end

    # Perform a POST request with a JSON body.
    # @return [String, Hash]
    def post(path, body = {})
      request_with_retry(:post, path, body)
    end

    # Perform a DELETE request.
    def delete(path)
      request_with_retry(:delete, path)
    end

    private

    def build_connection
      Faraday.new(url: @base_url) do |f|
        f.options.timeout      = @timeout
        f.options.open_timeout = @timeout
        f.headers["X-Api-Key"]      = @api_key
        f.headers["Authorization"]  = "Bearer #{@api_key}"
        f.headers["Content-Type"]   = "application/json"
        f.headers["Accept"]         = "*/*"
        f.headers["User-Agent"]     = "snapapi-ruby/#{SnapAPI::VERSION}"
        f.adapter Faraday.default_adapter
      end
    end

    def request_with_retry(method, path, body = nil)
      attempt = 0
      begin
        attempt += 1
        execute(method, path, body)
      rescue RateLimitError => e
        raise if attempt > @max_retries
        sleep([e.retry_after, MAX_RETRY_DELAY].min)
        retry
      rescue Error => e
        raise if attempt > @max_retries
        raise unless retryable?(e)
        sleep(compute_backoff(attempt))
        retry
      rescue Faraday::TimeoutError => e
        raise if attempt > @max_retries
        sleep(compute_backoff(attempt))
        raise TimeoutError, "Request timed out: #{e.message}" unless attempt <= @max_retries
        retry
      rescue Faraday::ConnectionFailed, Faraday::SSLError => e
        raise NetworkError, "Network error: #{e.message}"
      end
    end

    def execute(method, path, body)
      response = @conn.run_request(method, path, body ? JSON.generate(body) : nil, nil)
      handle_response(response)
    end

    def handle_response(response)
      code = response.status

      if code >= 400
        raise parse_error(code, response.body, response)
      end

      # Binary responses (images, PDF, video)
      content_type = response.headers["content-type"] || ""
      if content_type.start_with?("image/", "application/pdf", "video/")
        return response.body
      end

      # JSON response
      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        response.body
      end
    end

    def parse_error(status_code, body, response)
      data = begin
               JSON.parse(body || "{}")
             rescue JSON::ParserError
               {}
             end

      message = data["message"] || "HTTP #{status_code}"
      code    = data["error"] || "HTTP_ERROR"
      details = data["details"]

      if code.is_a?(Hash)
        message = code["message"] || message
        code    = code["code"]    || "HTTP_ERROR"
      end
      code = code.to_s.tr(" ", "_").upcase

      case status_code
      when 401, 403
        AuthenticationError.new(message, details: details)
      when 402
        QuotaExceededError.new(message, details: details)
      when 422
        fields = data["fields"] || {}
        ValidationError.new(message, fields: fields, details: details)
      when 429
        retry_after = (response.headers["retry-after"] || data["retryAfter"] || 1.0).to_f
        RateLimitError.new(message, retry_after: retry_after, details: details)
      else
        Error.new(message, code: code, status_code: status_code, details: details)
      end
    end

    def retryable?(error)
      error.status_code >= 500 || error.status_code == 0
    end

    def compute_backoff(attempt)
      delay = @retry_delay * (2**(attempt - 1))
      [delay, MAX_RETRY_DELAY].min
    end
  end
end
