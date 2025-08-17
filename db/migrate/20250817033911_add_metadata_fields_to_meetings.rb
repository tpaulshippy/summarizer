class AddMetadataFieldsToMeetings < ActiveRecord::Migration[8.0]
  def change
    add_column :meetings, :duration, :integer
    add_column :meetings, :channel_name, :string
    add_column :meetings, :description, :text
  end
end
