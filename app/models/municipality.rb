class Municipality < ApplicationRecord
  has_many :meetings, dependent: :destroy

  validates :name, presence: true
  validates :youtube_playlist_url, presence: true
  validates :slug, presence: true, uniqueness: true

  def to_param
    slug.presence || super
  end
end
