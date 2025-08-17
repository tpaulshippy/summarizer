class IngestPlaylistsJob < ApplicationJob
  queue_as :default

  def perform
    scraper = PlaylistScraper.new
    Municipality.find_each do |m|
      items = scraper.fetch_playlist_items(m.youtube_playlist_url)
      items.each do |item|
        meeting = Meeting.find_by(video_id: item[:video_id])

        if meeting
          # Update existing meeting if transcript or summary is blank, or if metadata is missing
          needs_transcript = meeting.transcript.blank?
          needs_summary = meeting.summary.blank?
          needs_metadata = meeting.duration.blank? || meeting.channel_name.blank? || meeting.description.nil?

          if needs_transcript || needs_summary || needs_metadata
            if needs_transcript
              transcript = TranscriptFetcher.fetch_text_for(item[:video_id])
              meeting.update(transcript: transcript) if transcript.present?
            end

            if needs_summary && meeting.transcript.present?
              summary = MeetingSummarizer.new.summarize(meeting)
              meeting.update(summary: summary) if summary.present?
            end

            if needs_metadata
              meeting.update(
                duration: item[:duration]&.to_i,
                channel_name: item[:channel_name],
                description: item[:description]
              )
            end
          end
        else
          # Create new meeting
          transcript = TranscriptFetcher.fetch_text_for(item[:video_id])

          meeting = m.meetings.create!(
            meeting_type: infer_meeting_type(item[:title], m.name),
            video_id: item[:video_id],
            video_url: item[:video_url],
            title: item[:title],
            transcript: transcript,
            held_on: item[:published_at] || infer_date_from_title(item[:title]) || Date.current,
            duration: item[:duration]&.to_i,
            channel_name: item[:channel_name],
            description: item[:description]
          )

          summary = MeetingSummarizer.new.summarize(meeting) if meeting.transcript.present?
          meeting.update(summary: summary) if summary.present?
        end
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
