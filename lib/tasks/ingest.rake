namespace :ingest do
  desc "Ingest playlists now"
  task playlists: :environment do
    IngestPlaylistsJob.perform_now
  end
end
