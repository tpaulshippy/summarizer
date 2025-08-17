class Meeting < ApplicationRecord
  belongs_to :municipality

  enum :meeting_type, {
    council: "council",
    planning: "planning",
    work_session: "work_session",
    other: "other"
  }, validate: false

  validates :video_id, presence: true, uniqueness: true
  validates :held_on, presence: true

  scope :recent, -> { order(held_on: :desc) }

  #after_create :schedule_transcript_fetch
  #after_update :schedule_summary_generation, if: :saved_change_to_transcript?

  private

  def schedule_transcript_fetch
    FetchTranscriptJob.perform_later(id) if transcript.blank?
  end

  def schedule_summary_generation
    schedule_transcript_fetch
    GenerateSummaryJob.perform_later(id) if transcript.present? && summary.blank?
  end
end
