class BillProcessingJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform(bill_id)
    bill = Bill.find(bill_id)

    # Atomically claim the bill only if it is still pending. This prevents
    # duplicate work when a reset races an already-running job.
    claimed = Bill.where(id: bill.id, processing_status: "pending")
                  .update_all(processing_status: "processing", updated_at: Time.current) > 0
    unless claimed
      Rails.logger.info "[BillProcessingJob] Skipping bill #{bill_id}: status is #{bill.processing_status}"
      return
    end
    bill.reload

    Bill.transaction do
      bill.bill_phrases.destroy_all
      bill.bill_question_selections.destroy_all
      bill.generated_questions.generated.destroy_all
      bill.update!(review_notes: nil)
    end

    PolicyPost::DataPipeline::Classification.call(bill)
    phrases = PolicyPost::DataPipeline::PhraseExtraction.call(bill)

    %w[support oppose].each do |position|
      PolicyPost::DataPipeline::QuestionGeneration.call(bill, position: position)
      selections = PolicyPost::DataPipeline::QuestionSelection.call(bill, position: position)
      PolicyPost::DataPipeline::PhraseMatching.call(bill, phrases: phrases, selections: selections)
    end

    bill.update!(processing_status: "review")
  rescue StandardError => e
    if bill
      if e.is_a?(PolicyPost::SlmUnavailableError)
        bill.update_columns(processing_status: "pending",
                            review_notes: "SLM unreachable: #{e.message}")
        Rails.logger.warn "[BillProcessingJob] Bill #{bill_id} SLM unreachable, resetting to pending: #{e.message}"
      elsif executions >= 3
        bill.update_columns(processing_status: "rejected",
                            review_notes: "Processing failed: #{e.class}: #{e.message}")
        Rails.logger.error "[BillProcessingJob] Bill #{bill_id} failed (attempt #{executions}): #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}"
        raise
      else
        bill.update_columns(processing_status: "pending")
        Rails.logger.error "[BillProcessingJob] Bill #{bill_id} failed (attempt #{executions}): #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}"
        raise
      end
    else
      Rails.logger.error "[BillProcessingJob] Bill #{bill_id} failed before find: #{e.class}: #{e.message}"
      raise
    end
  end
end
