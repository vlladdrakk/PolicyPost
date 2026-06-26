module PolicyPost::DataPipeline::Classification
  module_function

  def call(bill)
    result, is_fallback = classify(bill)
    bill.update!(category: result)
    if is_fallback
      bill.update!(review_notes: "Classification defaulted to governance after 2 SLM attempts")
    end
  end

  def classify(bill)
    prompt = PolicyPost::Prompts.classification(
      bill_number: bill.bill_number,
      title: bill.title,
      summary: bill.summary.to_s
    )

    attempts = 0
    loop do
      attempts += 1
      raw = PolicyPost::SlmClient.complete(prompt, temperature: 0.3)
      cleaned = clean_response(raw)
      Rails.logger.info "[Classification] Bill #{bill.bill_number} attempt #{attempts}: raw=#{raw.inspect} cleaned=#{cleaned.inspect}"

      if valid_category?(cleaned)
        return [ cleaned, false ]
      elsif attempts < 2
        next
      else
        Rails.logger.warn "[Classification] Bill #{bill.bill_number} fell back to 'governance' after #{attempts} attempts"
        return [ "governance", true ]
      end
    end
  rescue => e
    raise if e.is_a?(PolicyPost::SlmUnavailableError)
    Rails.logger.error "[Classification] Bill #{bill.bill_number} error: #{e.message}"
    [ "governance", true ]
  end

  def clean_response(raw)
    raw.to_s.strip.downcase
  end

  def valid_category?(category)
    DomainConstants::CATEGORIES.include?(category)
  end
end
