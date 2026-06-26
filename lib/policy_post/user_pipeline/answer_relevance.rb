module PolicyPost::UserPipeline::AnswerRelevance
  module_function

  FOLLOW_UPS = [
    "Can you give a specific example?",
    "When did you first notice or experience this?",
    "Who else is affected by this that you know of?",
    "How has this affected your day-to-day?",
    "Why does this matter to you personally?"
  ].freeze

  def check(question:, answer:, slm_client: nil)
    cleaned = answer.to_s.strip
    return { verdict: "good", follow_up: nil } if cleaned.blank? || cleaned.downcase == "i don't know"

    prompt = PolicyPost::Prompts.answer_relevance(question: question, answer: cleaned)
    raw = PolicyPost::SlmClient.complete(prompt, temperature: 0.3, client: slm_client)
    verdict = raw.to_s.strip.downcase
    verdict = "good" unless %w[good vague].include?(verdict)

    follow_up = nil
    if verdict == "vague"
      follow_up = select_follow_up(question: question, answer: cleaned, slm_client: slm_client)
    end

    { verdict: verdict, follow_up: follow_up }
  rescue => e
    Rails.logger.error "[AnswerRelevance] Error: #{e.message}"
    { verdict: "good", follow_up: nil }
  end

  def select_follow_up(question:, answer:, slm_client: nil)
    prompt = PolicyPost::Prompts.answer_follow_up(question: question, answer: answer)
    raw = PolicyPost::SlmClient.complete(prompt, temperature: 0.3, client: slm_client)
    number = raw.to_s.strip
    idx = number.to_i - 1
    return FOLLOW_UPS[idx] if idx >= 0 && idx < FOLLOW_UPS.size
    FOLLOW_UPS[0]
  rescue => e
    FOLLOW_UPS[0]
  end
end
