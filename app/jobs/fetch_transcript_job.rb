class FetchTranscriptJob < ApplicationJob
  queue_as :default

  def perform(meeting_id)
    meeting = Meeting.find(meeting_id)
    return if meeting.transcript.present?

    transcript = TranscriptFetcher.fetch_text_for(meeting.video_id)
    meeting.update(transcript: transcript) if transcript.present?
  rescue => e
    Rails.logger.error("FetchTranscriptJob error for meeting #{meeting_id}: #{e.message}")
    raise e
  end
end
