require "ruby_llm"

class MeetingSummarizer
  def initialize(model: "openai/gpt-oss-20b:free")
    @chat = RubyLLM::Chat.new(provider: :openrouter, model: model, assume_model_exists: true)
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

    response = @chat
      .with_instructions("You write clear, neutral, factual summaries.")
      .ask(prompt)

    response.content
  rescue => e
    Rails.logger.error("Summary error: #{e.message}")
    raise e
  end
end
