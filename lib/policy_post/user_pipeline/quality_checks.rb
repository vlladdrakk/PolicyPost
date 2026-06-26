module PolicyPost::UserPipeline::QualityChecks
  module_function

  def run(email_text:, letter:, slm_client: nil)
    rep = letter.representative
    bill = letter.bill
    config = PolicyPost::Config::POSITION_CONFIG[letter.position]

    qa_pairs = letter.intake_answers.includes(:question).map do |ia|
      "Q: #{ia.question.body}\nA: #{ia.answer}"
    end.join("\n\n")

    results = {}

    results["bill_accuracy"] = run_llm_check(
      PolicyPost::Prompts.quality_bill_accuracy(email: email_text, bill_number: bill.bill_number, title: bill.title),
      slm_client: slm_client
    )

    results["position_accuracy"] = run_llm_check(
      PolicyPost::Prompts.quality_position_accuracy(email: email_text, position: letter.position, position_verb: config[:position_verb]),
      slm_client: slm_client
    )

    results["hallucination"] = run_llm_check(
      PolicyPost::Prompts.quality_hallucination(email: email_text, qa_pairs: qa_pairs, bill_number: bill.bill_number, title: bill.title),
      slm_client: slm_client
    )

    results["placeholder"] = PolicyPost::EmailQuality.check_placeholders(email_text)

    results["tone"] = run_llm_check(
      PolicyPost::Prompts.quality_tone(email: email_text),
      slm_client: slm_client
    )

    results["length"] = PolicyPost::EmailQuality.check_length(email_text)

    PolicyPost::EmailQuality.process_quality_results(results)
  rescue => e
    Rails.logger.error "[QualityChecks] Error: #{e.message}"
    PolicyPost::EmailQuality::EmailQualityReport.new(status: "show_with_warnings", warnings: [ "Quality check error: #{e.message}" ])
  end

  def run_llm_check(prompt, slm_client: nil)
    raw = PolicyPost::SlmClient.complete(prompt, temperature: 0.3, client: slm_client)
    raw.to_s.strip.downcase == "pass"
  rescue => e
    false
  end
end
