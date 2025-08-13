require "open3"

class TranscriptFetcher
  PYTHON_SCRIPT = Rails.root.join("get_transcript.py").to_s

  def self.fetch_text_for(video_id)
    output_file = Rails.root.join("tmp", "#{video_id}_transcript.txt").to_s
    cmd = ["python3", PYTHON_SCRIPT, video_id, output_file]
    stdout_str, stderr_str, status = Open3.capture3(*cmd)
    unless status.success?
      Rails.logger.error("Transcript fetch failed: #{stderr_str}\n#{stdout_str}")
      return nil
    end
    File.read(output_file)
  rescue => e
    Rails.logger.error("Transcript fetch error: #{e.message}")
    nil
  end
end
