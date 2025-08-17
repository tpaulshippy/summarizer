class FetchTranscriptJob < ApplicationJob
  queue_as :default

  def perform(meeting_id)
    meeting = Meeting.find(meeting_id)
    return if meeting.transcript.present?

    transcript = TranscriptFetcher.fetch_text_for(meeting.video_id)
    if transcript.present?
      meeting.update(transcript: transcript)
    else
      Rails.logger.info("Transcript fetch returned nil for meeting #{meeting_id} (video_id: #{meeting.video_id}) - likely in cloud environment")
    end
  rescue => e
    Rails.logger.error("FetchTranscriptJob error for meeting #{meeting_id}: #{e.message}")
    raise e
  end
end
