module PolicyPost::DataPipeline::PhraseExtraction
  module_function

  def call(bill)
    extract_with_retry(bill)
  end

  def extract_with_retry(bill)
    questions = questions_needing_phrases(bill)

    extracted = run_extraction(bill, questions, extra_instruction: nil)
    verified = PolicyPost::PhraseVerification.verify_phrases(extracted, bill.full_text.to_s)

    if verified.size < 3
      Rails.logger.info "[PhraseExtraction] Bill #{bill.bill_number}: #{verified.size} verified, retrying with verbatim instruction"
      extracted2 = run_extraction(bill, questions, extra_instruction: "Ensure all phrases appear verbatim in the bill text.")
      verified = PolicyPost::PhraseVerification.verify_phrases(extracted2, bill.full_text.to_s)
    end

    if verified.size < 3
      Rails.logger.warn "[PhraseExtraction] Bill #{bill.bill_number}: still #{verified.size} verified after retry, using fallback"
      fallback = build_fallback_phrases(bill)
      verified = fallback
    end

    create_phrases(bill, verified)
  rescue => e
    raise if e.is_a?(PolicyPost::SlmUnavailableError)
    Rails.logger.error "[PhraseExtraction] Bill #{bill.bill_number} error: #{e.message}"
    create_phrases(bill, build_fallback_phrases(bill))
  end

  def run_extraction(bill, questions, extra_instruction:)
    prompt = PolicyPost::Prompts.phrase_extraction(
      bill_number: bill.bill_number,
      title: bill.title,
      summary: bill.summary.to_s,
      questions_needing_phrases: questions,
      extra_instruction: extra_instruction
    )

    raw = PolicyPost::SlmClient.complete(prompt, temperature: 0.5)
    Rails.logger.info "[PhraseExtraction] Bill #{bill.bill_number} raw response: #{raw.inspect}"
    parse_phrases(raw)
  end

  def parse_phrases(raw)
    raw.to_s.lines.map(&:strip).reject(&:empty?)
  end

  def questions_needing_phrases(bill)
    Question.active.where(category: bill.category).select(&:requires_bill_subject?).map(&:body)
  end

  def build_fallback_phrases(bill)
    if bill.short_title.present?
      [ bill.short_title ]
    else
      [ "Bill #{bill.bill_number}" ]
    end
  end

  def create_phrases(bill, phrases)
    phrases.map do |phrase_text|
      BillPhrase.create!(
        bill: bill,
        phrase: phrase_text,
        verified: PolicyPost::PhraseVerification.verify_phrases([ phrase_text ], bill.full_text.to_s).any?
      )
    end
  end
end
