class GenerateSummaryJob < ApplicationJob
  queue_as :default

  def perform(meeting_id)
    meeting = Meeting.find(meeting_id)
    return if meeting.summary.present? || meeting.transcript.blank?

    summary = MeetingSummarizer.new.summarize(meeting)
    meeting.update(summary: summary) if summary.present?
  rescue => e
    Rails.logger.error("GenerateSummaryJob error for meeting #{meeting_id}: #{e.message}")
    raise e
  end
end
