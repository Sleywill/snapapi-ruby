# frozen_string_literal: true

module SnapAPI
  # Official SnapAPI Ruby client.
  #
  # == Quick Start
  #
  #   client = SnapAPI::Client.new(api_key: "sk_live_...")
  #
  #   # Take a screenshot
  #   png = client.screenshot(url: "https://example.com")
  #   File.binwrite("screenshot.png", png)
  #
  #   # Save directly to file
  #   client.screenshot_to_file("https://example.com", "screenshot.png")
  #
  # == Configuration Block
  #
  #   SnapAPI.configure do |config|
  #     config.api_key = "sk_live_..."
  #   end
  #   client = SnapAPI::Client.new
  #
  # == Direct Configuration
  #
  #   client = SnapAPI::Client.new(
  #     api_key:     "sk_live_...",
  #     base_url:    "https://api.snapapi.pics",
  #     timeout:     60,
  #     max_retries: 3,
  #     retry_delay: 0.5,
  #   )
  class Client
    # @param api_key [String, nil] Your SnapAPI key. Falls back to SnapAPI.configuration.api_key.
    # @param base_url [String, nil] Override the API base URL.
    # @param timeout [Integer, nil] Request timeout in seconds (default: 60).
    # @param max_retries [Integer, nil] Auto-retry limit on 429/5xx (default: 3).
    # @param retry_delay [Float, nil] Initial backoff delay in seconds (default: 0.5).
    def initialize(api_key: nil, base_url: nil, timeout: nil, max_retries: nil, retry_delay: nil)
      config = SnapAPI.configuration
      resolved_key = api_key || config.api_key
      raise ArgumentError, "api_key is required" if resolved_key.nil? || resolved_key.empty?

      @http = HttpClient.new(
        api_key:     resolved_key,
        base_url:    base_url    || config.base_url,
        timeout:     timeout     || config.timeout,
        max_retries: max_retries || config.max_retries,
        retry_delay: retry_delay || config.retry_delay,
      )
    end

    # -------------------------------------------------------------------------
    # Screenshot  POST /v1/screenshot
    # -------------------------------------------------------------------------

    # Capture a screenshot of a URL, raw HTML, or Markdown string.
    #
    # @param url [String] Page URL to capture.
    # @param html [String] Raw HTML string to render (alternative to url).
    # @param markdown [String] Markdown string to render (alternative to url).
    # @param format [String] "png", "jpeg", "webp", "avif", or "pdf".
    # @param quality [Integer, nil] Image quality 1-100 (JPEG/WebP only).
    # @param device [String, nil] Named device viewport preset.
    # @param width [Integer] Viewport width (default: 1280).
    # @param height [Integer] Viewport height (default: 800).
    # @param device_scale_factor [Float] Device pixel ratio 1-3 (default: 1.0).
    # @param is_mobile [Boolean] Emulate a mobile device.
    # @param has_touch [Boolean] Enable touch events.
    # @param full_page [Boolean] Capture the full scrollable page.
    # @param full_page_scroll_delay [Integer, nil] Delay between scroll steps (ms).
    # @param full_page_max_height [Integer, nil] Maximum height for full-page (px).
    # @param selector [String, nil] CSS selector -- capture only that element.
    # @param delay [Integer] Extra delay before capture in ms.
    # @param timeout [Integer, nil] Navigation timeout in ms.
    # @param wait_until [String, nil] Navigation event to wait for.
    # @param wait_for_selector [String, nil] CSS selector to wait for.
    # @param dark_mode [Boolean] Emulate dark colour scheme.
    # @param reduced_motion [Boolean] Reduce CSS animations.
    # @param css [String, nil] Custom CSS to inject.
    # @param javascript [String, nil] JavaScript to run before capture.
    # @param hide_selectors [Array<String>, nil] CSS selectors to hide.
    # @param click_selector [String, nil] CSS selector to click before capture.
    # @param block_ads [Boolean] Block ad networks.
    # @param block_trackers [Boolean] Block tracking scripts.
    # @param block_cookie_banners [Boolean] Block cookie consent banners.
    # @param block_chat_widgets [Boolean] Block chat widgets.
    # @param user_agent [String, nil] Custom User-Agent string.
    # @param extra_headers [Hash, nil] Extra HTTP request headers.
    # @param cookies [Array<Hash>, nil] Cookies to inject.
    # @param http_auth [Hash, nil] HTTP Basic Auth credentials.
    # @param proxy [Hash, nil] Custom proxy configuration.
    # @param premium_proxy [Boolean, nil] Use SnapAPI rotating proxy.
    # @param geolocation [Hash, nil] GPS coordinates to emulate.
    # @param timezone [String, nil] IANA timezone string.
    # @param storage [Hash, nil] Store result in cloud.
    # @param webhook_url [String, nil] Deliver result to this webhook URL.
    # @param job_id [String, nil] Poll a previously queued async job.
    # @param page_size [String, nil] PDF page size.
    # @param landscape [Boolean, nil] PDF landscape orientation.
    # @param margins [Hash, nil] PDF page margins.
    #
    # @return [String] Raw image/PDF bytes for direct captures.
    # @return [Hash] JSON result when storage or webhook_url is provided.
    #
    # @raise [ArgumentError] when no input source is given.
    # @raise [SnapAPI::Error] on API errors.
    def screenshot(url: nil, html: nil, markdown: nil, format: "png", quality: nil,
                   device: nil, width: 1280, height: 800, device_scale_factor: 1.0,
                   is_mobile: false, has_touch: false, full_page: false,
                   full_page_scroll_delay: nil, full_page_max_height: nil,
                   selector: nil, delay: 0, timeout: nil, wait_until: nil,
                   wait_for_selector: nil, dark_mode: false, reduced_motion: false,
                   css: nil, javascript: nil, hide_selectors: nil, click_selector: nil,
                   block_ads: false, block_trackers: false, block_cookie_banners: false,
                   block_chat_widgets: false, user_agent: nil, extra_headers: nil,
                   cookies: nil, http_auth: nil, proxy: nil, premium_proxy: nil,
                   geolocation: nil, timezone: nil, storage: nil, webhook_url: nil,
                   job_id: nil, page_size: nil, landscape: nil, margins: nil)

      raise ArgumentError, "One of url, html, or markdown is required" if url.nil? && html.nil? && markdown.nil?

      payload = compact_hash(
        url: url, html: html, markdown: markdown, format: format,
        quality: quality, device: device, width: width, height: height,
        deviceScaleFactor: device_scale_factor.to_f,
        isMobile: is_mobile, hasTouch: has_touch,
        fullPage: full_page, fullPageScrollDelay: full_page_scroll_delay,
        fullPageMaxHeight: full_page_max_height,
        selector: selector, delay: delay, timeout: timeout,
        waitUntil: wait_until, waitForSelector: wait_for_selector,
        darkMode: dark_mode, reducedMotion: reduced_motion,
        css: css, javascript: javascript, hideSelectors: hide_selectors,
        clickSelector: click_selector, blockAds: block_ads,
        blockTrackers: block_trackers, blockCookieBanners: block_cookie_banners,
        blockChatWidgets: block_chat_widgets, userAgent: user_agent,
        extraHeaders: extra_headers, cookies: cookies,
        httpAuth: http_auth, proxy: proxy, premiumProxy: premium_proxy,
        geolocation: geolocation, timezone: timezone,
        storage: storage, webhookUrl: webhook_url, jobId: job_id,
        pageSize: page_size, landscape: landscape, margins: margins
      )

      # Remove false boolean values to keep payload clean
      payload.delete_if { |_, v| v == false }

      result = @http.post("/v1/screenshot", payload)
      result.is_a?(Hash) ? ScreenshotResult.new(result) : result
    end

    # Capture a screenshot and save it to a local file.
    #
    # @param url [String] URL to capture.
    # @param filepath [String] Destination file path.
    # @param **kwargs Additional screenshot options.
    # @return [Integer] Number of bytes written.
    def screenshot_to_file(url, filepath, **kwargs)
      kwargs.delete(:storage)
      kwargs.delete(:webhook_url)
      bytes = screenshot(url: url, **kwargs)
      raise TypeError, "Expected binary response but got #{bytes.class}" unless bytes.is_a?(String)
      File.binwrite(filepath, bytes)
    end

    # -------------------------------------------------------------------------
    # PDF  POST /v1/screenshot (format=pdf)
    # -------------------------------------------------------------------------

    # Generate a PDF from a URL or HTML string.
    #
    # @param url [String] Page URL to convert.
    # @param html [String, nil] Raw HTML to convert.
    # @param page_size [String] Paper size: "a4", "letter", etc. (default: "a4").
    # @param landscape [Boolean] Landscape orientation.
    # @param margins [Hash, nil] Page margins with keys top/right/bottom/left.
    # @param header_template [String, nil] HTML template for the page header.
    # @param footer_template [String, nil] HTML template for the page footer.
    # @param display_header_footer [Boolean] Show header and footer.
    # @param scale [Float, nil] Content scale factor 0.1-2.
    # @param delay [Integer] Extra delay before rendering (ms).
    # @param wait_for_selector [String, nil] CSS selector to wait for.
    #
    # @return [String] Raw PDF bytes.
    def pdf(url: nil, html: nil, page_size: "a4", landscape: false, margins: nil,
            header_template: nil, footer_template: nil, display_header_footer: false,
            scale: nil, delay: 0, wait_for_selector: nil)

      raise ArgumentError, "One of url or html is required" if url.nil? && html.nil?

      payload = compact_hash(
        url: url, html: html, format: "pdf", pageSize: page_size,
        landscape: landscape || nil, margins: margins,
        headerTemplate: header_template, footerTemplate: footer_template,
        displayHeaderFooter: display_header_footer || nil,
        scale: scale, delay: (delay > 0 ? delay : nil),
        waitForSelector: wait_for_selector
      )

      @http.post("/v1/screenshot", payload)
    end

    # Generate a PDF and save it to a local file.
    #
    # @param url [String] URL to convert.
    # @param filepath [String] Destination file path.
    # @param **kwargs Additional PDF options.
    # @return [Integer] Number of bytes written.
    def pdf_to_file(url, filepath, **kwargs)
      bytes = pdf(url: url, **kwargs)
      File.binwrite(filepath, bytes)
    end

    # Alias for {#pdf}. Generates a PDF document.
    #
    # @param url [String, nil] Page URL to convert.
    # @param html [String, nil] Raw HTML to convert.
    # @param **kwargs Additional PDF options.
    # @return [String] Raw PDF bytes.
    def generate_pdf(url: nil, html: nil, **kwargs)
      pdf(url: url, html: html, **kwargs)
    end

    # -------------------------------------------------------------------------
    # Scrape  POST /v1/scrape
    # -------------------------------------------------------------------------

    # Scrape text, HTML, or links from one or more pages.
    #
    # @param url [String] URL to scrape (required).
    # @param type [String] "text", "html", or "links" (default: "text").
    # @param pages [Integer] Number of pages to scrape 1-10 (default: 1).
    # @param wait_ms [Integer, nil] Wait time after page load (ms).
    # @param proxy [String, nil] Proxy URL.
    # @param premium_proxy [Boolean, nil] Use SnapAPI rotating proxy.
    # @param block_resources [Boolean] Block images/fonts/media.
    # @param locale [String, nil] Browser locale, e.g. "en-US".
    #
    # @return [SnapAPI::ScrapeResult]
    def scrape(url:, type: "text", pages: 1, wait_ms: nil, proxy: nil,
               premium_proxy: nil, block_resources: false, locale: nil)

      payload = compact_hash(
        url: url, type: type, pages: pages,
        waitMs: wait_ms, proxy: proxy, premiumProxy: premium_proxy,
        blockResources: block_resources || nil, locale: locale
      )
      ScrapeResult.new(@http.post("/v1/scrape", payload))
    end

    # -------------------------------------------------------------------------
    # Extract  POST /v1/extract
    # -------------------------------------------------------------------------

    # Extract structured content from a web page.
    #
    # @param url [String] URL to extract from (required).
    # @param type [String] "markdown", "text", "html", "article", "links",
    #   "images", "metadata", or "structured".
    # @param selector [String, nil] CSS selector to scope extraction.
    # @param wait_for [String, nil] CSS selector to wait for.
    # @param timeout [Integer, nil] Navigation timeout (ms).
    # @param dark_mode [Boolean] Emulate dark mode.
    # @param block_ads [Boolean] Block ad networks.
    # @param block_cookie_banners [Boolean] Block cookie consent banners.
    # @param include_images [Boolean, nil] Include image URLs.
    # @param max_length [Integer, nil] Truncate output at N characters.
    # @param clean_output [Boolean, nil] Strip navigation and boilerplate.
    #
    # @return [SnapAPI::ExtractResult]
    def extract(url:, type: "markdown", selector: nil, wait_for: nil, timeout: nil,
                dark_mode: false, block_ads: false, block_cookie_banners: false,
                include_images: nil, max_length: nil, clean_output: nil)

      payload = compact_hash(
        url: url, type: type, selector: selector, waitFor: wait_for,
        timeout: timeout, darkMode: dark_mode || nil,
        blockAds: block_ads || nil, blockCookieBanners: block_cookie_banners || nil,
        includeImages: include_images, maxLength: max_length, cleanOutput: clean_output
      )
      ExtractResult.new(@http.post("/v1/extract", payload))
    end

    # Extract page content as Markdown.
    # @param url [String]
    # @param **kwargs Additional extract options.
    # @return [SnapAPI::ExtractResult]
    def extract_markdown(url, **kwargs)
      kwargs.delete(:type)
      extract(url: url, type: "markdown", **kwargs)
    end

    # Extract main article body from a page.
    # @param url [String]
    # @param **kwargs Additional extract options.
    # @return [SnapAPI::ExtractResult]
    def extract_article(url, **kwargs)
      kwargs.delete(:type)
      extract(url: url, type: "article", **kwargs)
    end

    # Extract plain text from a page.
    # @param url [String]
    # @param **kwargs Additional extract options.
    # @return [SnapAPI::ExtractResult]
    def extract_text(url, **kwargs)
      kwargs.delete(:type)
      extract(url: url, type: "text", **kwargs)
    end

    # Extract all hyperlinks from a page.
    # @param url [String]
    # @param **kwargs Additional extract options.
    # @return [SnapAPI::ExtractResult]
    def extract_links(url, **kwargs)
      kwargs.delete(:type)
      extract(url: url, type: "links", **kwargs)
    end

    # Extract all image URLs from a page.
    # @param url [String]
    # @param **kwargs Additional extract options.
    # @return [SnapAPI::ExtractResult]
    def extract_images(url, **kwargs)
      kwargs.delete(:type)
      extract(url: url, type: "images", **kwargs)
    end

    # Extract page metadata (title, description, OG tags, etc.).
    # @param url [String]
    # @param **kwargs Additional extract options.
    # @return [SnapAPI::ExtractResult]
    def extract_metadata(url, **kwargs)
      kwargs.delete(:type)
      extract(url: url, type: "metadata", **kwargs)
    end

    # -------------------------------------------------------------------------
    # Video  POST /v1/video
    # -------------------------------------------------------------------------

    # Record a video of a live webpage.
    #
    # @param url [String] URL to record (required).
    # @param format [String] "mp4", "webm", or "gif" (default: "mp4").
    # @param width [Integer] Viewport width 320-1920 (default: 1280).
    # @param height [Integer] Viewport height 240-1080 (default: 720).
    # @param duration [Integer] Recording duration in seconds 1-30 (default: 5).
    # @param fps [Integer] Frames per second 10-30 (default: 25).
    # @param scrolling [Boolean] Enable automatic scroll animation.
    # @param dark_mode [Boolean] Enable dark mode.
    # @param block_ads [Boolean] Block ad networks.
    # @param block_cookie_banners [Boolean] Block cookie consent banners.
    # @param delay [Integer] Delay before recording starts (ms).
    #
    # @return [String] Raw video bytes.
    def video(url:, format: "mp4", width: 1280, height: 720, duration: 5, fps: 25,
              scrolling: false, scroll_speed: nil, scroll_delay: nil,
              scroll_duration: nil, scroll_by: nil, scroll_easing: nil,
              scroll_back: true, scroll_complete: true,
              dark_mode: false, block_ads: false, block_cookie_banners: false, delay: 0)

      payload = compact_hash(
        url: url, format: format, width: width, height: height,
        duration: duration, fps: fps,
        scrolling: scrolling || nil, scrollSpeed: scroll_speed,
        scrollDelay: scroll_delay, scrollDuration: scroll_duration,
        scrollBy: scroll_by, scrollEasing: scroll_easing,
        scrollBack: scroll_back.nil? ? nil : scroll_back,
        scrollComplete: scroll_complete.nil? ? nil : scroll_complete,
        darkMode: dark_mode || nil,
        blockAds: block_ads || nil,
        blockCookieBanners: block_cookie_banners || nil,
        delay: (delay > 0 ? delay : nil)
      )

      @http.post("/v1/video", payload)
    end

    # -------------------------------------------------------------------------
    # OG Image
    # -------------------------------------------------------------------------

    # Generate an Open Graph image (1200x630) for a URL.
    #
    # @param url [String] URL to generate an OG image for.
    # @param format [String] Output format (default: "png").
    # @param width [Integer] Image width (default: 1200).
    # @param height [Integer] Image height (default: 630).
    #
    # @return [String] Raw image bytes.
    def og_image(url:, format: "png", width: 1200, height: 630)
      @http.post("/v1/screenshot", { url: url, format: format, width: width, height: height })
    end

    # Alias for {#og_image}. Generates an Open Graph social preview image.
    #
    # @param url [String] URL to generate an OG image for.
    # @param format [String] Output format (default: "png").
    # @param width [Integer] Image width (default: 1200).
    # @param height [Integer] Image height (default: 630).
    # @return [String] Raw image bytes.
    def generate_og_image(url:, format: "png", width: 1200, height: 630)
      og_image(url: url, format: format, width: width, height: height)
    end

    # -------------------------------------------------------------------------
    # Analyze  POST /v1/analyze
    # -------------------------------------------------------------------------

    # Analyze a web page with an LLM.
    #
    # @param url [String] URL to analyze (required).
    # @param prompt [String] Analysis prompt (required).
    # @param provider [String, nil] LLM provider: "openai" or "anthropic".
    # @param api_key [String, nil] Your LLM provider API key.
    # @param model [String, nil] Override the default model.
    # @param json_schema [Hash, nil] JSON schema for structured output.
    # @param include_screenshot [Boolean, nil] Include screenshot context.
    # @param include_metadata [Boolean, nil] Include page metadata context.
    # @param max_content_length [Integer, nil] Max characters of page content.
    # @param timeout [Integer, nil] Navigation timeout (ms).
    # @param block_ads [Boolean] Block ad networks.
    # @param block_cookie_banners [Boolean] Block cookie consent banners.
    # @param wait_for [String, nil] CSS selector to wait for.
    #
    # @return [SnapAPI::AnalyzeResult]
    def analyze(url:, prompt:, provider: nil, api_key: nil, model: nil,
                json_schema: nil, include_screenshot: nil, include_metadata: nil,
                max_content_length: nil, timeout: nil, block_ads: false,
                block_cookie_banners: false, wait_for: nil)

      payload = compact_hash(
        url: url, prompt: prompt, provider: provider, apiKey: api_key,
        model: model, jsonSchema: json_schema,
        includeScreenshot: include_screenshot, includeMetadata: include_metadata,
        maxContentLength: max_content_length, timeout: timeout,
        blockAds: block_ads || nil, blockCookieBanners: block_cookie_banners || nil,
        waitFor: wait_for
      )
      AnalyzeResult.new(@http.post("/v1/analyze", payload))
    end

    # -------------------------------------------------------------------------
    # Usage / Quota
    # -------------------------------------------------------------------------

    # Get API usage for the current billing period.
    #
    # @return [SnapAPI::UsageResult]
    def get_usage
      UsageResult.new(@http.get("/v1/usage"))
    end

    # Alias for #get_usage.
    # @return [SnapAPI::UsageResult]
    def quota
      get_usage
    end

    # -------------------------------------------------------------------------
    # Ping
    # -------------------------------------------------------------------------

    # Check API availability.
    #
    # @return [Hash] { "status" => "ok", "timestamp" => <unix ms> }
    def ping
      @http.get("/v1/ping")
    end

    private

    # Remove nil values from a hash to produce a clean API payload.
    def compact_hash(**kv)
      kv.reject { |_, v| v.nil? }
    end
  end
end
