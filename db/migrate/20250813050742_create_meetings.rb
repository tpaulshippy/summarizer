class CreateMeetings < ActiveRecord::Migration[8.0]
  def change
    create_table :meetings do |t|
      t.references :municipality, null: false, foreign_key: true
      t.string :meeting_type
      t.string :video_id
      t.string :video_url
      t.date :held_on
      t.text :transcript
      t.text :summary
      t.string :title

      t.timestamps
    end
    add_index :meetings, :video_id
  end
end
