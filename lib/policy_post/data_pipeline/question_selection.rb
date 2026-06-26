module PolicyPost::DataPipeline::QuestionSelection
  module_function

  CONFIG = PolicyPost::Config::QUESTION_SELECTION_CONFIG

  def call(bill, position:)
    selections = select_questions(bill, position)
    create_selections(bill, selections, position)
  end

  def select_questions(bill, position)
    candidates = build_candidates(bill, position)
    return rule_based_fallback(candidates) if candidates.empty?

    questions_list = format_questions_list(candidates)
    prompt = PolicyPost::Prompts.question_selection(
      bill_number: bill.bill_number,
      title: bill.title,
      summary: bill.summary.to_s,
      category: bill.category,
      position: position,
      questions_list: questions_list
    )

    attempts = 0
    loop do
      attempts += 1
      raw = PolicyPost::SlmClient.complete(prompt, temperature: 0.3)
      Rails.logger.info "[QuestionSelection] Bill #{bill.bill_number} pos=#{position} attempt #{attempts}: raw=#{raw.inspect}"
      ids = parse_ids(raw)

      selected = candidates.select { |c| ids.include?(c[:id].to_s) }
      if valid_selection?(selected, candidates)
        return deduplicate(selected).first(CONFIG[:max_count])
      elsif attempts < 2
        next
      else
        Rails.logger.warn "[QuestionSelection] Bill #{bill.bill_number} pos=#{position} fell back to rule-based after #{attempts} attempts"
        return rule_based_fallback(candidates)
      end
    end
  rescue => e
    raise if e.is_a?(PolicyPost::SlmUnavailableError)
    Rails.logger.error "[QuestionSelection] Bill #{bill.bill_number} pos=#{position} error: #{e.message}"
    candidates = build_candidates(bill, position)
    rule_based_fallback(candidates)
  end

  def build_candidates(bill, position)
    templates = Question.templates.active
      .for_category_and_position(bill.category, position)
      .map do |q|
        { id: q.id, source: :template, record: q, body: q.body, type: q.question_type }
      end

    generated = Question.generated.active.approved
      .for_bill(bill)
      .where(position: position)
      .map do |q|
        { id: q.id, source: :generated, record: q, body: q.body, type: q.question_type }
      end

    (templates + generated).uniq { |c| c[:body].downcase.strip }
  end

  def format_questions_list(candidates)
    candidates.map.with_index do |c, i|
      source_tag = c[:source] == :generated ? "[BILL-SPECIFIC]" : "[TEMPLATE]"
      "#{i + 1}. [#{c[:id]}] #{source_tag} (#{c[:type]}) #{c[:body]}"
    end.join("\n")
  end

  def parse_ids(raw)
    raw.to_s.strip.split(",").map(&:strip).reject(&:empty?).map(&:to_i).reject(&:zero?)
  end

  def valid_selection?(selected, candidates)
    return false if selected.size < CONFIG[:min_count]
    return false if selected.size > CONFIG[:max_count]
    return false if selected.any? { |s| candidates.none? { |c| c[:id] == s[:id] } }
    return false if selected.map { |s| s[:type] }.uniq.size < 2

    true
  end

  def deduplicate(selected)
    seen = Set.new
    selected.select do |item|
      normalized = item[:body].downcase.gsub(/[^a-z0-9\s]/, " ").squeeze(" ").strip
      next false if seen.any? { |s| similar_text?(normalized, s) }
      seen << normalized
      true
    end
  end

  def similar_text?(a, b)
    return true if a == b
    a_words = a.split
    b_words = b.split
    return false if a_words.empty? || b_words.empty?

    overlap = (a_words & b_words).size
    shorter = [ a_words.size, b_words.size ].min
    overlap.to_f / shorter >= 0.75
  end

  def rule_based_fallback(candidates)
    generated = candidates.select { |c| c[:source] == :generated }
    templates = candidates.select { |c| c[:source] == :template }.sort_by { |c| [ c[:record].priority, c[:record].id ] }

    chosen = generated.first(CONFIG[:target_count])
    remaining_slots = CONFIG[:target_count] - chosen.size
    chosen += templates.first(remaining_slots) if remaining_slots > 0

    deduplicate(chosen).first(CONFIG[:max_count])
  end

  def create_selections(bill, candidates, position)
    BillQuestionSelection.where(bill: bill, position: position).destroy_all
    candidates.map do |candidate|
      BillQuestionSelection.create!(
        bill: bill,
        question: candidate[:record],
        position: position
      )
    end
  end
end
