module PolicyPost::EmailQuality
  module_function

  EmailQualityReport = Struct.new(:status, :warnings, :retry_approach, keyword_init: true)

  FAILURE_WARNINGS = {
    "bill_accuracy" => "The bill reference may be incorrect — please verify before sending.",
    "position_accuracy" => "The position expressed may not match your intent — please review.",
    "hallucination" => "Some details may not reflect your answers — please verify the content is accurate.",
    "placeholder" => "Personal detail placeholders are missing — add your name and address.",
    "tone" => "The tone may not be appropriate — please review for formality.",
    "length" => "The email is over 300 words — consider trimming."
  }.freeze

  def check_placeholders(email_text)
    email_text.include?("[YOUR_FULL_NAME]") && email_text.include?("[YOUR_ADDRESS]")
  end

  def check_length(email_text, max_words: 300)
    email_text.split.size <= max_words
  end

  def process_quality_results(results, alternate_approach: nil)
    failures = results.select { |_name, passed| !passed }.keys
    return EmailQualityReport.new(status: "pass", warnings: []) if failures.empty?
    return EmailQualityReport.new(status: "pass_with_warning", warnings: [ FAILURE_WARNINGS[failures.first] ]) if failures.size == 1
    return EmailQualityReport.new(status: "retry", warnings: [], retry_approach: alternate_approach) if failures.size <= 2

    EmailQualityReport.new(status: "show_with_warnings", warnings: failures.map { |f| FAILURE_WARNINGS[f] })
  end
end
