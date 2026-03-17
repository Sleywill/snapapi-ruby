# frozen_string_literal: true

module SnapAPI
  # Lightweight immutable value object backed by a Hash.
  # All keys are accessible as methods (snake_case).
  class Response
    attr_reader :raw

    def initialize(data)
      @raw = data.is_a?(Hash) ? data : {}
    end

    def [](key)
      @raw[key.to_s] || @raw[key.to_sym]
    end

    def to_h
      @raw
    end

    def to_s
      @raw.inspect
    end

    def inspect
      "#<#{self.class.name} #{@raw.inspect}>"
    end

    private

    def method_missing(name, *args)
      key = name.to_s
      return @raw[key] if @raw.key?(key)
      # Try camelCase variant
      camel = key.gsub(/_([a-z])/) { $1.upcase }
      return @raw[camel] if @raw.key?(camel)
      super
    end

    def respond_to_missing?(name, include_private = false)
      key = name.to_s
      @raw.key?(key) || @raw.key?(key.gsub(/_([a-z])/) { $1.upcase }) || super
    end
  end

  # Response returned by #screenshot, #pdf when stored/webhoooked.
  class ScreenshotResult < Response
    def url;    self["url"];                        end
    def job_id; self["jobId"] || self["job_id"];   end
    def status; self["status"];                     end
  end

  # Response returned by #scrape.
  class ScrapeResult < Response
    # @return [Array<Hash>] list of scraped page results
    def results; Array(self["results"]); end
    def url;     self["url"];            end
  end

  # Response returned by #extract.
  class ExtractResult < Response
    def content;  self["content"];   end
    def url;      self["url"];       end
    def type;     self["type"];      end
    def metadata; self["metadata"]; end
  end

  # Response returned by #analyze.
  class AnalyzeResult < Response
    def result;   self["result"];   end
    def model;    self["model"];    end
    def provider; self["provider"]; end
    def url;      self["url"];      end
  end

  # Response returned by #video.
  # Raw bytes are stored separately; this wraps async/storage responses.
  class VideoResult < Response
    def url;    self["url"];                       end
    def job_id; self["jobId"] || self["job_id"];  end
    def status; self["status"];                    end
  end

  # Response returned by #get_usage / #quota.
  class UsageResult < Response
    def used;      self["used"];                              end
    def limit;     self["limit"];                             end
    def remaining; self["remaining"];                         end
    def reset_at;  self["resetAt"] || self["reset_at"];      end
  end

  # Generic success/delete result.
  class DeleteResult < Response
    def success; self["success"]; end
  end

  # A stored file entry.
  class StorageFile < Response
    def id;         self["id"];                                  end
    def url;        self["url"];                                 end
    def filename;   self["filename"];                            end
    def size;       self["size"];                                end
    def created_at; self["createdAt"] || self["created_at"];    end
  end
end
