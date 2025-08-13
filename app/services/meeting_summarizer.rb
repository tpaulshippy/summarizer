class MeetingSummarizer
  def initialize(model: "anthropic/claude-3-5-haiku")
    @client = RubyLLM::Client.new(provider: :anthropic, model: model)
  end

  def summarize(meeting)
    prompt = <<~TEXT
      You are a civic meeting summarizer. Read the transcript below and produce:
      - A concise 3-6 bullet summary focusing on decisions, votes, and notable discussions.
      - A short paragraph overview.
      - List any follow-up actions or deadlines.

      Transcript:
      #{meeting.transcript}
    TEXT

    response = @client.chat(messages: [
      { role: :system, content: "You write clear, neutral, factual summaries." },
      { role: :user, content: prompt }
    ])

    response.output
  rescue => e
    Rails.logger.error("Summary error: #{e.message}")
    nil
  end
end
