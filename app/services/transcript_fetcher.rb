require "open3"

class TranscriptFetcher
  PYTHON_SCRIPT = Rails.root.join("get_transcript.py").to_s
  PYTHON_EXECUTABLE = Rails.root.join("venv", "bin", "python").to_s

  def self.fetch_text_for(video_id)
    if Rails.env.production? && cloud_environment?
      Rails.logger.info("Skipping transcript fetch in cloud environment for video_id: #{video_id}")
      return nil
    end

    output_file = Rails.root.join("tmp", "#{video_id}_transcript.txt").to_s
    cmd = [ PYTHON_EXECUTABLE, PYTHON_SCRIPT, video_id, output_file ]
    stdout_str, stderr_str, status = Open3.capture3(*cmd)
    unless status.success?
      if stdout_str.include?("Transcripts are disabled for this video.") || stderr_str.include?("Transcripts are disabled for this video.")
        raise "Transcripts are disabled for video_id: #{video_id}"
      end

      Rails.logger.error("Transcript fetch failed: #{stderr_str}\n#{stdout_str}")
      raise "Transcript fetch failed: #{stderr_str}\n#{stdout_str}"
    end
    File.read(output_file)
  rescue => e
    Rails.logger.error("Transcript fetch error: #{e.message}")
    if Rails.env.production? && cloud_environment?
      Rails.logger.info("Transcript fetch failed in cloud environment - will need manual upload")
      return nil
    end
    raise e
  end

  private

  def self.cloud_environment?
    ENV['KAMAL_DEPLOY'].present? || ENV['RENDER'].present? || ENV['HEROKU'].present? || !File.exist?(PYTHON_EXECUTABLE)
  end
end
