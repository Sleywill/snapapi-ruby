# frozen_string_literal: true

module SnapAPI
  # Base exception for all SnapAPI errors.
  #
  # @attr_reader message [String] Human-readable error description.
  # @attr_reader code [String] Machine-readable error code from the API.
  # @attr_reader status_code [Integer] HTTP status code (0 for network errors).
  # @attr_reader details [Object, nil] Optional extra payload from the API.
  class Error < StandardError
    attr_reader :message, :code, :status_code, :details

    def initialize(message = "An unexpected error occurred", code: "UNKNOWN_ERROR", status_code: 500, details: nil)
      super(message)
      @message     = message
      @code        = code
      @status_code = status_code
      @details     = details
    end

    def to_s
      "[#{@code}] #{@message}"
    end

    def inspect
      "#<#{self.class.name} message=#{@message.inspect} code=#{@code.inspect} status_code=#{@status_code}>"
    end
  end

  # Raised when the API returns HTTP 401 or 403.
  class AuthenticationError < Error
    def initialize(message = "Authentication failed", details: nil)
      super(message, code: "UNAUTHORIZED", status_code: 401, details: details)
    end
  end

  # Raised when the API returns HTTP 429 Too Many Requests.
  # The SDK retries automatically up to +max_retries+ times.
  #
  # @attr_reader retry_after [Float] Seconds to wait before retrying.
  class RateLimitError < Error
    attr_reader :retry_after

    def initialize(message = "Rate limit exceeded", retry_after: 1.0, details: nil)
      super(message, code: "RATE_LIMITED", status_code: 429, details: details)
      @retry_after = retry_after.to_f
    end
  end

  # Raised when the account has exhausted its API quota (HTTP 402).
  class QuotaExceededError < Error
    def initialize(message = "API quota exceeded", details: nil)
      super(message, code: "QUOTA_EXCEEDED", status_code: 402, details: details)
    end
  end

  # Raised when the API returns HTTP 422 Unprocessable Entity.
  #
  # @attr_reader fields [Hash] Per-field validation messages, if provided.
  class ValidationError < Error
    attr_reader :fields

    def initialize(message = "Validation error", fields: {}, details: nil)
      super(message, code: "VALIDATION_ERROR", status_code: 422, details: details)
      @fields = fields || {}
    end
  end

  # Raised when a request times out before the API responds.
  class TimeoutError < Error
    def initialize(message = "Request timed out")
      super(message, code: "TIMEOUT", status_code: 0)
    end
  end

  # Raised on network-level failures (DNS, connection refused, etc.).
  class NetworkError < Error
    def initialize(message)
      super(message, code: "NETWORK_ERROR", status_code: 0)
    end
  end
end
