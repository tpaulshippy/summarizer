class CreateMunicipalities < ActiveRecord::Migration[8.0]
  def change
    create_table :municipalities do |t|
      t.string :name
      t.string :youtube_playlist_url
      t.string :slug

      t.timestamps
    end
    add_index :municipalities, :slug, unique: true
  end
end
