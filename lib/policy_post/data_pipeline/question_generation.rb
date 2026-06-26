module PolicyPost::DataPipeline::QuestionGeneration
  module_function

  CONFIG = PolicyPost::Config::QUESTION_GENERATION_CONFIG

  def call(bill, position:)
    candidates = generate_candidates(bill, position)
    valid = validate_candidates(candidates, bill, position)
    create_questions(bill, valid, position)
  rescue => e
    raise if e.is_a?(PolicyPost::SlmUnavailableError)
    Rails.logger.error "[QuestionGeneration] Bill #{bill.bill_number} pos=#{position} error: #{e.message}"
    []
  end

  def generate_candidates(bill, position)
    phrases = bill.bill_phrases.verified.pluck(:phrase)
    prompt = PolicyPost::Prompts.bill_specific_question_generation(
      bill_number: bill.bill_number,
      title: bill.title,
      summary: bill.summary.to_s,
      position: position,
      position_description: PolicyPost::Config::POSITION_CONFIG.dig(position, :position_description),
      verified_phrases: phrases
    )

    raw = PolicyPost::SlmClient.complete(prompt, temperature: 0.6)
    Rails.logger.info "[QuestionGeneration] Bill #{bill.bill_number} pos=#{position} raw: #{raw.inspect}"
    parse_questions(raw)
  end

  def parse_questions(raw)
    raw.to_s.lines.map(&:strip).reject(&:empty?).reject { |line| line.start_with?("#", "-") }
  end

  def validate_candidates(candidates, bill, position)
    templates = template_bodies(bill, position)
    anchors = bill_anchors(bill)

    seen = Set.new
    candidates.select do |candidate|
      next false unless candidate.end_with?("?")
      next false if candidate.length < 20

      normalized = candidate.downcase
      next false if seen.include?(normalized)
      next false if templates.any? { |t| similar?(normalized, t) }
      next false unless anchors.any? { |a| normalized.include?(a) }

      seen << normalized
      true
    end.first(CONFIG[:max_count])
  end

  def template_bodies(bill, position)
    fallback_subject = bill.short_title.presence || bill.bill_number
    Question.templates.active
      .for_category_and_position(bill.category, position)
      .pluck(:body)
      .map { |body| body.gsub("{bill_subject}", fallback_subject).downcase }
  end

  def bill_anchors(bill)
    anchors = [ bill.bill_number.downcase ]
    anchors << bill.short_title.downcase if bill.short_title.present?
    anchors.concat(bill.title.downcase.split.first(5))
    anchors.concat(bill.bill_phrases.verified.pluck(:phrase).map(&:downcase))
    anchors.uniq
  end

  def similar?(a, b)
    return true if a == b
    return true if a.include?(b) || b.include?(a)

    a_words = a.split
    b_words = b.split
    return false if a_words.empty? || b_words.empty?

    overlap = (a_words & b_words).size
    shorter = [ a_words.size, b_words.size ].min
    overlap.to_f / shorter >= 0.7
  end

  def create_questions(bill, bodies, position)
    bodies.map do |body|
      Question.create!(
        bill: bill,
        category: bill.category,
        position: position,
        question_type: "generated",
        priority: 0,
        active: true,
        source: "generated",
        status: "pending",
        body: body
      )
    end
  end
end
