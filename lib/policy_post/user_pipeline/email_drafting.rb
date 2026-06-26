module PolicyPost::UserPipeline::EmailDrafting
  module_function

  def draft(letter, slm_client: nil)
    rep = letter.representative
    bill = letter.bill
    config = PolicyPost::Config::POSITION_CONFIG[letter.position]

    qa_pairs = letter.intake_answers.includes(:question).map do |ia|
      "Q: #{ia.question.body.gsub("{bill_subject}", bill.short_title || bill.bill_number)}\nA: #{ia.answer}"
    end.join("\n\n")

    user_riding = letter.riding&.name
    constituent_description = letter.local_mp? ? "a constituent of #{user_riding}" : "a concerned Canadian"

    bill_origin = bill.senate_bill? ? "Senate" : "House of Commons"

    prompt = PolicyPost::Prompts.email_drafting_a(
      rep_title: rep.title,
      rep_name: rep.name,
      rep_riding: user_riding || "Canada",
      is_minister: rep.is_minister,
      ministry_name: rep.ministry_name,
      bill_number: bill.bill_number,
      bill_title: bill.title,
      bill_origin: bill_origin,
      position: letter.position,
      user_riding: user_riding || "Canada",
      constituent_description: constituent_description,
      qa_pairs: qa_pairs,
      position_config: config
    )

    raw = PolicyPost::SlmClient.complete(prompt, temperature: 0.5, client: slm_client)
    raw.to_s.strip
  rescue => e
    Rails.logger.error "[EmailDrafting] Error: #{e.message}"
    "[Error generating draft. Please try again.]"
  end
end
