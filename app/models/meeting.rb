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

  after_create :schedule_transcript_fetch
  after_update :schedule_summary_generation, if: :saved_change_to_transcript?

  def schedule_transcript_fetch
    FetchTranscriptJob.perform_later(id) if transcript.blank?
  end

  def schedule_summary_generation
    schedule_transcript_fetch
    GenerateSummaryJob.perform_later(id) if transcript.present? && summary.blank?
  end

  def self.find_or_create_from_playlist_item(municipality, item)
    meeting_date = extract_meeting_date(item)
    meeting = find_by(video_id: item[:video_id])

    if meeting
      meeting.update_from_playlist_item(item, meeting_date)
    else
      create_from_playlist_item(municipality, item, meeting_date)
    end
  end

  def update_from_playlist_item(item, meeting_date)
    update_metadata_if_needed(item)
    update_date_if_changed(meeting_date)
    schedule_processing_if_needed
  end

  def self.create_from_playlist_item(municipality, item, meeting_date)
    municipality.meetings.create!(
      meeting_type: infer_meeting_type(item[:title], municipality.name),
      video_id: item[:video_id],
      video_url: item[:video_url],
      title: item[:title],
      held_on: meeting_date,
      duration: item[:duration]&.to_i,
      channel_name: item[:channel_name],
      description: item[:description]
    )
  end

  private

  def self.extract_meeting_date(item)
    item[:published_at] || infer_date_from_title(item[:title]) || Date.current
  end

  def self.infer_date_from_title(title)
    Date.parse(title)
  rescue
    nil
  end

  def self.infer_meeting_type(title, municipality_name)
    normalized = title.to_s.downcase
    return "council" if normalized.include?("council")
    return "planning" if normalized.include?("planning") || normalized.include?("zoning")
    return "work_session" if normalized.include?("work session") || normalized.include?("study session")
    "other"
  end

  def needs_metadata_update?
    duration.blank? || channel_name.blank? || description.nil?
  end

  def update_metadata_if_needed(item)
    return unless needs_metadata_update?

    update(
      duration: item[:duration]&.to_i,
      channel_name: item[:channel_name],
      description: item[:description]
    )
  end

  def update_date_if_changed(meeting_date)
    update(held_on: meeting_date) if held_on != meeting_date
  end

  def schedule_processing_if_needed
    if transcript.blank?
      schedule_transcript_fetch
    elsif summary.blank?
      schedule_summary_generation
    end
  end
end
