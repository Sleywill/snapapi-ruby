# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SnapAPI error classes" do
  # ---------------------------------------------------------------------------
  # SnapAPI::Error (base)
  # ---------------------------------------------------------------------------

  describe SnapAPI::Error do
    subject(:error) { described_class.new("Something broke", code: "BROKEN", status_code: 503) }

    it "is a StandardError" do
      expect(error).to be_a(StandardError)
    end

    it "exposes #message" do
      expect(error.message).to eq("Something broke")
    end

    it "exposes #code" do
      expect(error.code).to eq("BROKEN")
    end

    it "exposes #status_code" do
      expect(error.status_code).to eq(503)
    end

    it "exposes nil #details by default" do
      expect(described_class.new("msg").details).to be_nil
    end

    it "stores arbitrary #details payload" do
      err = described_class.new("msg", details: { field: "url" })
      expect(err.details).to eq({ field: "url" })
    end

    it "#to_s includes code and message" do
      expect(error.to_s).to include("BROKEN")
      expect(error.to_s).to include("Something broke")
    end

    it "#inspect includes class name, message, status_code" do
      text = error.inspect
      expect(text).to include("SnapAPI::Error")
      expect(text).to include("503")
    end

    it "uses defaults when called with just a message" do
      e = described_class.new("oops")
      expect(e.code).to eq("UNKNOWN_ERROR")
      expect(e.status_code).to eq(500)
    end
  end

  # ---------------------------------------------------------------------------
  # SnapAPI::AuthenticationError
  # ---------------------------------------------------------------------------

  describe SnapAPI::AuthenticationError do
    subject(:error) { described_class.new }

    it "is a SnapAPI::Error" do
      expect(error).to be_a(SnapAPI::Error)
    end

    it "has status_code 401" do
      expect(error.status_code).to eq(401)
    end

    it "has code UNAUTHORIZED" do
      expect(error.code).to eq("UNAUTHORIZED")
    end

    it "accepts a custom message" do
      e = described_class.new("Bad token")
      expect(e.message).to eq("Bad token")
    end
  end

  # ---------------------------------------------------------------------------
  # SnapAPI::RateLimitError
  # ---------------------------------------------------------------------------

  describe SnapAPI::RateLimitError do
    subject(:error) { described_class.new("Too many requests", retry_after: 5.0) }

    it "is a SnapAPI::Error" do
      expect(error).to be_a(SnapAPI::Error)
    end

    it "has status_code 429" do
      expect(error.status_code).to eq(429)
    end

    it "has code RATE_LIMITED" do
      expect(error.code).to eq("RATE_LIMITED")
    end

    it "exposes #retry_after as Float" do
      expect(error.retry_after).to eq(5.0)
    end

    it "defaults retry_after to 1.0" do
      expect(described_class.new.retry_after).to eq(1.0)
    end

    it "coerces retry_after to Float" do
      e = described_class.new(retry_after: "3")
      expect(e.retry_after).to be_a(Float)
      expect(e.retry_after).to eq(3.0)
    end
  end

  # ---------------------------------------------------------------------------
  # SnapAPI::QuotaExceededError
  # ---------------------------------------------------------------------------

  describe SnapAPI::QuotaExceededError do
    subject(:error) { described_class.new }

    it "is a SnapAPI::Error" do
      expect(error).to be_a(SnapAPI::Error)
    end

    it "has status_code 402" do
      expect(error.status_code).to eq(402)
    end

    it "has code QUOTA_EXCEEDED" do
      expect(error.code).to eq("QUOTA_EXCEEDED")
    end
  end

  # ---------------------------------------------------------------------------
  # SnapAPI::ValidationError
  # ---------------------------------------------------------------------------

  describe SnapAPI::ValidationError do
    subject(:error) { described_class.new("Invalid params", fields: { url: "is required" }) }

    it "is a SnapAPI::Error" do
      expect(error).to be_a(SnapAPI::Error)
    end

    it "has status_code 422" do
      expect(error.status_code).to eq(422)
    end

    it "has code VALIDATION_ERROR" do
      expect(error.code).to eq("VALIDATION_ERROR")
    end

    it "exposes #fields hash" do
      expect(error.fields).to eq({ url: "is required" })
    end

    it "defaults fields to empty hash" do
      expect(described_class.new.fields).to eq({})
    end

    it "handles nil fields gracefully" do
      e = described_class.new("msg", fields: nil)
      expect(e.fields).to eq({})
    end
  end

  # ---------------------------------------------------------------------------
  # SnapAPI::TimeoutError
  # ---------------------------------------------------------------------------

  describe SnapAPI::TimeoutError do
    subject(:error) { described_class.new }

    it "is a SnapAPI::Error" do
      expect(error).to be_a(SnapAPI::Error)
    end

    it "has status_code 0" do
      expect(error.status_code).to eq(0)
    end

    it "has code TIMEOUT" do
      expect(error.code).to eq("TIMEOUT")
    end

    it "accepts a custom message" do
      e = described_class.new("Timed out after 60s")
      expect(e.message).to include("60s")
    end
  end

  # ---------------------------------------------------------------------------
  # SnapAPI::NetworkError
  # ---------------------------------------------------------------------------

  describe SnapAPI::NetworkError do
    subject(:error) { described_class.new("DNS resolution failed") }

    it "is a SnapAPI::Error" do
      expect(error).to be_a(SnapAPI::Error)
    end

    it "has status_code 0" do
      expect(error.status_code).to eq(0)
    end

    it "has code NETWORK_ERROR" do
      expect(error.code).to eq("NETWORK_ERROR")
    end

    it "stores the message" do
      expect(error.message).to eq("DNS resolution failed")
    end
  end

  # ---------------------------------------------------------------------------
  # Rescuability
  # ---------------------------------------------------------------------------

  describe "rescue hierarchy" do
    it "can rescue AuthenticationError as SnapAPI::Error" do
      raised = false
      begin
        raise SnapAPI::AuthenticationError
      rescue SnapAPI::Error
        raised = true
      end
      expect(raised).to be true
    end

    it "can rescue RateLimitError as StandardError" do
      raised = false
      begin
        raise SnapAPI::RateLimitError
      rescue StandardError
        raised = true
      end
      expect(raised).to be true
    end

    it "can rescue any SnapAPI::Error as StandardError" do
      [
        SnapAPI::AuthenticationError,
        SnapAPI::RateLimitError,
        SnapAPI::QuotaExceededError,
        SnapAPI::ValidationError,
        SnapAPI::TimeoutError,
      ].each do |klass|
        expect { raise klass }.to raise_error(StandardError)
      end
    end
  end
end
