module PolicyPost::PhraseVerification
  module_function

  RankedPhrase = Struct.new(:text, :rank, keyword_init: true)
  QuestionWithPhrases = Struct.new(:id, :phrases, keyword_init: true)

  def verify_phrases(phrases, bill_text)
    verified = []
    normalized_text = bill_text.to_s.downcase
    phrases.each do |phrase|
      normalized_phrase = phrase.to_s.downcase.strip
      if normalized_text.include?(normalized_phrase)
        verified << phrase
      else
        words = normalized_phrase.split
        verified << phrase if words.all? { |word| normalized_text.include?(word) }
      end
    end
    verified
  end

  def select_phrases(questions, session_counter: 0, strategy: "top_only", fallback: nil)
    selections = {}
    questions.each_with_index do |q, i|
      phrases = q.phrases
      if phrases&.any?
        case strategy
        when "round_robin"
          selections[q.id] = phrases[(session_counter + i) % phrases.size].text
        when "random"
          selections[q.id] = weighted_random_choice(phrases).text
        when "top_only"
          selections[q.id] = phrases.first.text
        else
          selections[q.id] = fallback
        end
      else
        selections[q.id] = fallback
      end
    end
    selections
  end

  def weighted_random_choice(phrases)
    weights = { 1 => 0.6, 2 => 0.25, 3 => 0.15 }
    total = phrases.sum { |p| weights.fetch(p.rank, 0.1) }
    r = rand * total
    cumulative = 0.0
    phrases.each do |p|
      cumulative += weights.fetch(p.rank, 0.1)
      return p if r <= cumulative
    end
    phrases.first
  end
end
