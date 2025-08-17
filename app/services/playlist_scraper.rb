require "open-uri"
require "json"
require "cgi"
require "date"
require "net/http"

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
    uri.open(REQUEST_HEADERS).read
  end

  def fetch_metadata_for(video_url)
    # Fetch the YouTube page HTML to extract metadata
    html = fetch_html(video_url)

    # Extract JSON-LD structured data which contains metadata
    json_ld_match = html.match(/<script type="application\/ld\+json"[^>]*>(.*?)<\/script>/m)
    if json_ld_match
      json_data = JSON.parse(json_ld_match[1])
      result = extract_from_json_ld(json_data)
      return result if result[:title].present?
    end

    # Fallback to extracting from page data
    result = extract_from_page_data(html)
    return result if result[:title].present?

    # Final fallback to oEmbed
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

    if player_response_match
      player_data = JSON.parse(player_response_match[1])
      video_details = player_data.dig("videoDetails")
      microformat = player_data.dig("microformat", "playerMicroformatRenderer")

      return {
        title: video_details&.dig("title"),
        published_at: parse_date(microformat&.dig("publishDate") || microformat&.dig("uploadDate")),
        duration: video_details&.dig("lengthSeconds"),
        description: video_details&.dig("shortDescription"),
        channel_name: video_details&.dig("author")
      }
    end

    # Try ytInitialData as fallback
    initial_data_match = html.match(/var ytInitialData\s*=\s*({.+?});/)
    if initial_data_match
      initial_data = JSON.parse(initial_data_match[1])
      # Navigate through the complex structure to find video info
      video_primary_info = initial_data.dig("contents", "twoColumnWatchNextResults", "results", "results", "contents")&.find do |item|
        item.dig("videoPrimaryInfoRenderer")
      end&.dig("videoPrimaryInfoRenderer")

      if video_primary_info
        return {
          title: video_primary_info.dig("title", "runs", 0, "text"),
          published_at: parse_date(video_primary_info.dig("dateText", "simpleText")),
          duration: nil,
          description: nil,
          channel_name: nil
        }
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
    json = URI.parse(url).open(REQUEST_HEADERS).read
    oembed_data = JSON.parse(json)

    {
      title: oembed_data["title"],
      published_at: nil,
      duration: nil,
      description: nil,
      channel_name: oembed_data["author_name"]
    }
  rescue => e
    Rails.logger.warn("oEmbed fallback failed for #{video_url}: #{e.message}")
    # Return empty metadata - the calling method will provide the video ID fallback
    {
      title: nil,
      published_at: nil,
      duration: nil,
      description: nil,
      channel_name: nil
    }
  end
end
