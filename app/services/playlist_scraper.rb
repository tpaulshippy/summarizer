require "open-uri"
require "json"
require "cgi"
require "date"
require "net/http"
require "zlib"

class PlaylistScraper
  YOUTUBE_OEMBED = "https://www.youtube.com/oembed?format=json&url="

  # More robust headers to avoid being blocked
  REQUEST_HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language" => "en-US,en;q=0.5",
    "Accept-Encoding" => "gzip, deflate",
    "Connection" => "keep-alive",
    "Upgrade-Insecure-Requests" => "1"
  }

  def initialize(http: Net::HTTP)
    @http = http
  end

  # Returns an array of hashes with keys: :video_id, :video_url, :title, :published_at, :duration, :description
  def fetch_playlist_items(playlist_url)
    # Fallback simple approach: use YouTube page and extract video ids via regex
    html = fetch_html(playlist_url)

    # Ensure HTML is properly encoded before scanning
    html = html.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?") unless html.valid_encoding?

    video_ids = html.scan(/"videoId":"([A-Za-z0-9_-]{11})"/).flatten.uniq
    video_ids.map do |vid|
      video_url = "https://www.youtube.com/watch?v=#{vid}"
      metadata = fetch_metadata_for(video_url)
      {
        video_id: vid,
        video_url: video_url,
        title: metadata[:title] || "Video #{vid}", # Fallback to descriptive title
        published_at: metadata[:published_at],
        duration: metadata[:duration],
        description: metadata[:description],
        channel_name: metadata[:channel_name]
      }
    end
  rescue => e
    Rails.logger.error("PlaylistScraper error: #{e.message}")
    []
  end

  # Yields each playlist item as it's processed instead of loading all into memory
  def each_playlist_item(playlist_url, &block)
    # Fallback simple approach: use YouTube page and extract video ids via regex
    html = fetch_html(playlist_url)

    # Ensure HTML is properly encoded before scanning
    html = html.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?") unless html.valid_encoding?

    video_ids = html.scan(/"videoId":"([A-Za-z0-9_-]{11})"/).flatten.uniq

    video_ids.each do |vid|
      video_url = "https://www.youtube.com/watch?v=#{vid}"
      metadata = fetch_metadata_for(video_url)

      # Better logging for debugging
      if metadata[:title].blank?
        Rails.logger.warn("Failed to extract title for video #{vid}, metadata: #{metadata}")
      end

      item = {
        video_id: vid,
        video_url: video_url,
        title: metadata[:title] || "Video #{vid}", # Fallback to descriptive title
        published_at: metadata[:published_at],
        duration: metadata[:duration],
        description: metadata[:description],
        channel_name: metadata[:channel_name]
      }
      yield(item)

      # Add a small delay to avoid rate limiting
      sleep(1)
    end
  rescue => e
    Rails.logger.error("PlaylistScraper error: #{e.message}")
    Rails.logger.error("PlaylistScraper backtrace: #{e.backtrace}")
  end

  private

  # Helper method to fetch HTML with proper headers
  def fetch_html(url)
    uri = URI.parse(url)
    io = uri.open(REQUEST_HEADERS)

    # Check if response is gzipped and decompress if needed
    response = if io.meta["content-encoding"] == "gzip"
                 Zlib::GzipReader.new(io).read
    else
                 io.read
    end

    # Ensure the response is properly encoded as UTF-8
    # This handles cases where the response contains invalid byte sequences
    response.force_encoding("UTF-8")

    # If it's not valid UTF-8, try to clean it up
    unless response.valid_encoding?
      # First try to convert from common encodings
      [ "ISO-8859-1", "Windows-1252" ].each do |encoding|
        begin
          cleaned = response.force_encoding(encoding).encode("UTF-8")
          return cleaned if cleaned.valid_encoding?
        rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
          next
        end
      end

      # If conversion fails, remove invalid bytes
      response = response.scrub("?")
    end

    response
  ensure
    io&.close
  end

  # Helper method to fetch JSON with proper headers and gzip handling
  def fetch_json(url)
    uri = URI.parse(url)
    io = uri.open(REQUEST_HEADERS)

    # Check if response is gzipped and decompress if needed
    response = if io.meta["content-encoding"] == "gzip"
                 Zlib::GzipReader.new(io).read
    else
                 io.read
    end

    # Ensure the response is properly encoded as UTF-8
    response.force_encoding("UTF-8")

    # Clean up encoding if needed
    unless response.valid_encoding?
      response = response.scrub("?")
    end

    response
  ensure
    io&.close
  end

  def fetch_metadata_for(video_url)
    # Fetch the YouTube page HTML to extract metadata
    html = fetch_html(video_url)

    # Debug logging to understand what we're getting
    Rails.logger.debug("HTML length for #{video_url}: #{html.length}")
    Rails.logger.debug("HTML contains 'application/ld+json': #{html.include?('application/ld+json')}")

    # Extract JSON-LD structured data which contains metadata
    # Try multiple patterns for JSON-LD scripts
    json_ld_match = html.match(/<script type="application\/ld\+json"[^>]*>(.*?)<\/script>/m) ||
                    html.match(/<script[^>]*type=['"]application\/ld\+json['"][^>]*>(.*?)<\/script>/m) ||
                    html.match(/<script[^>]*application\/ld\+json[^>]*>(.*?)<\/script>/m)

    Rails.logger.debug("JSON-LD match found: #{!json_ld_match.nil?}")

    # If no JSON-LD found, let's see what script tags we do have
    if json_ld_match.nil?
      script_tags = html.scan(/<script[^>]*type=['"]?([^'">\s]+)['"]?[^>]*>/i).flatten.uniq
      Rails.logger.debug("Available script types: #{script_tags}")
    end

    if json_ld_match
      begin
        json_data = JSON.parse(json_ld_match[1])
        result = extract_from_json_ld(json_data)
        return result if result[:title].present?
      rescue JSON::ParserError => e
        Rails.logger.warn("JSON-LD parsing failed for #{video_url}: #{e.message}")
      end
    end

    # Fallback to extracting from page data
    Rails.logger.debug("Trying page data extraction fallback for #{video_url}")
    result = extract_from_page_data(html)
    if result[:title].present?
      Rails.logger.debug("Page data extraction successful: #{result[:title]}")
      return result
    end

    # Fallback to basic HTML title extraction
    Rails.logger.debug("Trying HTML title extraction fallback for #{video_url}")
    title = extract_title_from_html(html)
    if title.present?
      Rails.logger.debug("HTML title extraction successful: #{title}")
      return {
        title: title,
        published_at: nil,
        duration: nil,
        description: nil,
        channel_name: nil
      }
    end

    # Final fallback to oEmbed
    Rails.logger.debug("Using oEmbed fallback for #{video_url}")
    fallback_oembed_data(video_url)
  rescue => e
    Rails.logger.error("Metadata extraction error for #{video_url}: #{e.message}")
    Rails.logger.error("Metadata extraction backtrace: #{e.backtrace}")
    fallback_oembed_data(video_url)
  end

  def extract_from_json_ld(json_data)
    # Handle both single objects and arrays
    data = json_data.is_a?(Array) ? json_data.first : json_data

    {
      title: data.dig("name"),
      published_at: parse_date(data.dig("uploadDate")),
      duration: data.dig("duration"),
      description: data.dig("description"),
      channel_name: data.dig("author", "name")
    }
  end

  def extract_from_page_data(html)
    # Extract from ytInitialPlayerResponse (try both patterns)
    player_response_match = html.match(/var ytInitialPlayerResponse\s*=\s*({.+?});/) ||
                           html.match(/"ytInitialPlayerResponse"\s*:\s*({.+?})\s*[,;}]/)

    Rails.logger.debug("ytInitialPlayerResponse found: #{!player_response_match.nil?}")

    if player_response_match
      begin
        player_data = JSON.parse(player_response_match[1])
        video_details = player_data.dig("videoDetails")
        microformat = player_data.dig("microformat", "playerMicroformatRenderer")

        Rails.logger.debug("Player data keys: #{player_data.keys}")
        Rails.logger.debug("Video details present: #{!video_details.nil?}")
        Rails.logger.debug("Video details keys: #{video_details&.keys}")
        Rails.logger.debug("Video title: #{video_details&.dig('title')}")

        result = {
          title: video_details&.dig("title"),
          published_at: parse_date(microformat&.dig("publishDate") || microformat&.dig("uploadDate")),
          duration: video_details&.dig("lengthSeconds"),
          description: video_details&.dig("shortDescription"),
          channel_name: video_details&.dig("author")
        }

        Rails.logger.debug("ytInitialPlayerResponse result: #{result}")
        return result if result[:title].present?
      rescue JSON::ParserError => e
        Rails.logger.warn("ytInitialPlayerResponse JSON parsing failed: #{e.message}")
      end
    end

    # Try ytInitialData as fallback
    initial_data_match = html.match(/var ytInitialData\s*=\s*({.+?});/)
    Rails.logger.debug("ytInitialData found: #{!initial_data_match.nil?}")

    if initial_data_match
      begin
        initial_data = JSON.parse(initial_data_match[1])
        Rails.logger.debug("ytInitialData keys: #{initial_data.keys}")

        # Navigate through the complex structure to find video info
        video_primary_info = initial_data.dig("contents", "twoColumnWatchNextResults", "results", "results", "contents")&.find do |item|
          item.dig("videoPrimaryInfoRenderer")
        end&.dig("videoPrimaryInfoRenderer")

        Rails.logger.debug("Video primary info found: #{!video_primary_info.nil?}")

        if video_primary_info
          result = {
            title: video_primary_info.dig("title", "runs", 0, "text"),
            published_at: parse_date(video_primary_info.dig("dateText", "simpleText")),
            duration: nil,
            description: nil,
            channel_name: nil
          }
          Rails.logger.debug("ytInitialData result: #{result}")
          return result if result[:title].present?
        end
      rescue JSON::ParserError => e
        Rails.logger.warn("ytInitialData JSON parsing failed: #{e.message}")
      end
    end

    # Final fallback to basic parsing
    {
      title: extract_title_from_html(html),
      published_at: nil,
      duration: nil,
      description: nil,
      channel_name: nil
    }
  end

  def extract_title_from_html(html)
    title_match = html.match(/<title[^>]*>(.*?)<\/title>/m)
    return nil unless title_match

    title = title_match[1].strip
    # Remove " - YouTube" suffix
    title.gsub(/ - YouTube$/, "")
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    # Handle ISO 8601 format
    Date.parse(date_string)
  rescue Date::Error
    nil
  end

  def fallback_oembed_data(video_url)
    # Fallback to oEmbed if all else fails
    url = YOUTUBE_OEMBED + CGI.escape(video_url)
    json = fetch_json(url)

    # Handle empty or invalid responses
    if json.blank? || json.strip.empty?
      Rails.logger.warn("oEmbed returned empty response for #{video_url}")
      return empty_metadata
    end

    oembed_data = JSON.parse(json)

    {
      title: oembed_data["title"],
      published_at: nil,
      duration: nil,
      description: nil,
      channel_name: oembed_data["author_name"]
    }
  rescue JSON::ParserError => e
    Rails.logger.warn("oEmbed JSON parsing failed for #{video_url}: #{e.message}")
    Rails.logger.warn("Raw oEmbed response: #{json[0..200].inspect}")
    empty_metadata
  rescue => e
    Rails.logger.warn("oEmbed fallback failed for #{video_url}: #{e.message}")
    empty_metadata
  end

  def empty_metadata
    {
      title: nil,
      published_at: nil,
      duration: nil,
      description: nil,
      channel_name: nil
    }
  end
end
