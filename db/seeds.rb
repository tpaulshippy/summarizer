# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
Municipality.find_or_create_by!(slug: "gilbert") do |m|
  m.name = "Gilbert"
  m.youtube_playlist_url = "https://www.youtube.com/playlist?list=PL515B03692F942503"
end

Municipality.find_or_create_by!(slug: "phoenix") do |m|
  m.name = "Phoenix"
  m.youtube_playlist_url = "https://www.youtube.com/playlist?list=PL22YB12L5NbTuJ_GPTxBJU4CKDII3fIB4"
end

Municipality.find_or_create_by!(slug: "scottsdale") do |m|
  m.name = "Scottsdale"
  m.youtube_playlist_url = "https://www.youtube.com/watch?v=JpMBZW-1F04&list=PLOKBvBs_6yw9NbVeQBllEXrilIqyi5eiP"
end

Municipality.find_or_create_by!(slug: "chandler") do |m|
  m.name = "Chandler"
  m.youtube_playlist_url = "https://www.youtube.com/playlist?list=PLJcsB9a3Oq8WdIjqW7qf91LsENrcIZIRu"
end
