class IngestPlaylistsJob < ApplicationJob
  queue_as :default

  def perform
    scraper = PlaylistScraper.new
    Municipality.find_each do |municipality|
      scraper.each_playlist_item(municipality.youtube_playlist_url) do |item|
        Meeting.find_or_create_from_playlist_item(municipality, item)
      end
    end
  end
end
