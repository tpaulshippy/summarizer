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
end
