module PolicyPost::DataPipeline::PhraseMatching
  module_function

  def call(bill, phrases:, selections:)
    selections_to_match = selections.select { |sel| sel.question.requires_bill_subject? }
    return [] if selections_to_match.empty?

    mappings = match_phrases(bill, phrases, selections_to_match)
    create_question_phrases(mappings, selections, phrases, bill)
  end

  def match_phrases(bill, phrases, selections_to_match)
    phrases_list = format_phrases_list(phrases)
    questions_list = format_questions_list(selections_to_match)

    prompt = PolicyPost::Prompts.phrase_matching(
      bill_number: bill.bill_number,
      title: bill.title,
      phrases_list: phrases_list,
      questions_list: questions_list
    )

    raw = PolicyPost::SlmClient.complete(prompt, temperature: 0.3)
    Rails.logger.info "[PhraseMatching] Bill #{bill.bill_number} raw response: #{raw.inspect}"
    parse_mappings(raw, phrases, selections_to_match, bill)
  rescue => e
    raise if e.is_a?(PolicyPost::SlmUnavailableError)
    Rails.logger.error "[PhraseMatching] Bill #{bill.bill_number} error: #{e.message}"
    fallback_mappings(selections_to_match, phrases)
  end

  def format_phrases_list(phrases)
    phrases.map.with_index { |p, i| "P#{i + 1}. #{p.phrase}" }.join("\n")
  end

  def format_questions_list(selections)
    selections.map.with_index { |sel, i| "Q#{i + 1}. #{sel.question.body}" }.join("\n")
  end

  def parse_mappings(raw, phrases, selections_to_match, bill)
    mappings = {}
    raw.to_s.lines.each do |line|
      line = line.strip
      next unless line.match?(/\AQ\d+=P\d+,P\d+,P\d+\z/)

      q_num, p_list = line.split("=")
      q_index = q_num.gsub("Q", "").to_i - 1
      p_indices = p_list.split(",").map { |p| p.gsub("P", "").to_i - 1 }

      next unless q_index >= 0 && q_index < selections_to_match.length
      next unless p_indices.all? { |pi| pi >= 0 && pi < phrases.length }
      next unless p_indices.size == 3

      mappings[selections_to_match[q_index].id] = p_indices
    end

    if mappings.empty?
      return fallback_mappings(selections_to_match, phrases)
    end

    selections_to_match.each do |sel|
      unless mappings.key?(sel.id)
        mappings[sel.id] = fill_missing(phrases, bill)
      end
    end

    mappings
  end

  def fill_missing(phrases, bill)
    top = phrases.first(3).map { |p| phrases.index(p) }
    while top.length < 3
      fallback_phrase = find_or_create_short_title_phrase(phrases, bill)
      fallback_index = phrases.index(fallback_phrase)
      top << (fallback_index || 0)
    end
    top
  end

  def find_or_create_short_title_phrase(phrases, bill)
    title = bill.short_title.presence || "Bill #{bill.bill_number}"
    existing = phrases.find { |p| p.phrase == title }
    return existing if existing

    BillPhrase.create!(
      bill: bill,
      phrase: title,
      verified: false
    ).tap { |bp| phrases << bp }
  end

  def fallback_mappings(selections_to_match, phrases)
    top3 = phrases.first(3).map { |p| phrases.index(p) }
    selections_to_match.to_h { |sel| [ sel.id, top3 ] }
  end

  def create_question_phrases(mappings, all_selections, phrases, bill)
    result = []
    mappings.each do |selection_id, phrase_indices|
      selection = all_selections.find { |s| s.id == selection_id }
      next unless selection

      phrase_indices.each_with_index do |p_idx, rank|
        next unless phrases[p_idx]
        result << QuestionPhrase.create!(
          bill_question_selection: selection,
          bill_phrase: phrases[p_idx],
          rank: rank + 1
        )
      end
    end
    result
  end

  def reassign(bill)
    selections = bill.bill_question_selections.includes(:question)
    phrases = bill.bill_phrases.verified.to_a
    return true if phrases.empty?

    selections.each do |sel|
      next unless sel.question.requires_bill_subject?

      sel.question_phrases.destroy_all

      question_words = sel.question.body.downcase.gsub(/[^a-z\s]/, " ").split.uniq
      scored = phrases.map do |p|
        phrase_words = p.phrase.downcase.split
        overlap = phrase_words.count { |w| question_words.include?(w) }
        [ p, overlap ]
      end
      top = scored.sort_by { |_, score| -score }.first(3).map(&:first)

      top.each_with_index do |phrase, rank|
        QuestionPhrase.create!(
          bill_question_selection: sel,
          bill_phrase: phrase,
          rank: rank + 1
        )
      end
    end

    true
  end
end
