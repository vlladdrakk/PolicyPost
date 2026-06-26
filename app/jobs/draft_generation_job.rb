class DraftGenerationJob < ApplicationJob
  queue_as :default
  self.priority = -10
  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform(draft_id)
    draft = EmailDraft.find(draft_id)
    return unless draft.status == "processing"

    letter = draft.constituent_letter
    email_text = PolicyPost::UserPipeline::EmailDrafting.draft(letter)
    quality = PolicyPost::UserPipeline::QualityChecks.run(email_text: email_text, letter: letter)

    draft.update!(
      body: email_text,
      quality_status: quality.status,
      quality_warnings: quality.warnings&.join("; ")
    )
    draft.complete!
  rescue => e
    Rails.logger.error "[DraftGenerationJob] Error: #{e.message}"
    draft&.reload
    draft&.failed! if draft&.status == "processing"
    raise
  end
end
