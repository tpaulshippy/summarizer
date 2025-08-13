require "open-uri"
require "json"
require "cgi"

class PlaylistScraper
  YOUTUBE_OEMBED = "https://www.youtube.com/oembed?format=json&url="

  def initialize(http: Net::HTTP)
    @http = http
  end

  # Returns an array of hashes with keys: :video_id, :video_url, :title
  def fetch_playlist_items(playlist_url)
    # Fallback simple approach: use YouTube page and extract video ids via regex
    html = URI.parse(playlist_url).open.read
    video_ids = html.scan(/"videoId":"([A-Za-z0-9_-]{11})"/).flatten.uniq
    video_ids.map do |vid|
      {
        video_id: vid,
        video_url: "https://www.youtube.com/watch?v=#{vid}",
        title: fetch_title_for("https://www.youtube.com/watch?v=#{vid}")
      }
    end
  rescue => e
    Rails.logger.error("PlaylistScraper error: #{e.message}")
    []
  end

  private

  def fetch_title_for(video_url)
    # Use oEmbed for a quick title fetch without API key
    url = YOUTUBE_OEMBED + CGI.escape(video_url)
    json = URI.parse(url).open.read
    JSON.parse(json).fetch("title", nil)
  rescue
    nil
  end
end
