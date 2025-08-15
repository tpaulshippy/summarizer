class IngestPlaylistsJob < ApplicationJob
  queue_as :default

  def perform
    scraper = PlaylistScraper.new
    Municipality.find_each do |m|
      items = scraper.fetch_playlist_items(m.youtube_playlist_url)
      items.each do |item|
        next if Meeting.exists?(video_id: item[:video_id])

        transcript = TranscriptFetcher.fetch_text_for(item[:video_id])

        meeting = m.meetings.create!(
          meeting_type: infer_meeting_type(item[:title], m.name),
          video_id: item[:video_id],
          video_url: item[:video_url],
          title: item[:title],
          transcript: transcript,
          held_on: infer_date_from_title(item[:title]) || Date.current
        )

        summary = MeetingSummarizer.new.summarize(meeting) if meeting.transcript.present?
        meeting.update(summary: summary) if summary.present?
      end
    end
  end

  private

  def infer_date_from_title(title)
    # Try to parse a date like "January 5, 2025" or "2025-01-05"
    Date.parse(title)
  rescue
    nil
  end

  def infer_meeting_type(title, municipality_name)
    normalized = title.to_s.downcase
    return "council" if normalized.include?("council")
    return "planning" if normalized.include?("planning") || normalized.include?("zoning")
    return "work_session" if normalized.include?("work session") || normalized.include?("study session")
    "other"
  end
end
