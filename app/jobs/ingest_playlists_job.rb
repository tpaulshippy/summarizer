class IngestPlaylistsJob < ApplicationJob
  queue_as :default

  def perform
    scraper = PlaylistScraper.new
    Municipality.find_each do |m|
      scraper.each_playlist_item(m.youtube_playlist_url) do |item|
        meeting = Meeting.find_by(video_id: item[:video_id])

        if meeting
          # Update existing meeting if metadata is missing
          needs_metadata = meeting.duration.blank? || meeting.channel_name.blank? || meeting.description.nil?

          if needs_metadata
            meeting.update(
              duration: item[:duration]&.to_i,
              channel_name: item[:channel_name],
              description: item[:description]
            )
          end
        else
          # Create new meeting - callbacks will handle transcript and summary
          m.meetings.create!(
            meeting_type: infer_meeting_type(item[:title], m.name),
            video_id: item[:video_id],
            video_url: item[:video_url],
            title: item[:title],
            held_on: item[:published_at] || infer_date_from_title(item[:title]) || Date.current,
            duration: item[:duration]&.to_i,
            channel_name: item[:channel_name],
            description: item[:description]
          )
        end

        break # just do one for now
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
