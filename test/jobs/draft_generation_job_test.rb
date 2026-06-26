require "test_helper"

class DraftGenerationJobTest < ActiveJob::TestCase
  setup do
    @letter = constituent_letters(:one)
  end

  def create_processing_draft
    draft = @letter.email_drafts.build(approach: "A", body: "placeholder")
    draft.processing!
    draft
  end

  test "processes draft from processing to complete" do
    draft = create_processing_draft

    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "Dear MP,\n\nI am writing as a constituent regarding Bill C-37.\n\nSincerely,\n[YOUR_FULL_NAME]\n[YOUR_ADDRESS]",
      "pass", "pass", "pass", "pass"
    ])
    PolicyPost::SlmClient.default_client = client

    perform_enqueued_jobs do
      DraftGenerationJob.perform_later(draft.id)
    end

    draft.reload
    assert_equal "complete", draft.status
    assert draft.body.length > 10
    assert_equal "pass", draft.quality_status
  end

  test "stores quality_warnings on single check failure" do
    draft = create_processing_draft

    # Draft text with placeholders so the programmatic checks pass.
    # Only bill_accuracy fails — single LLM failure → pass_with_warning.
    draft_text = "Dear MP,\n\nI am writing about Bill C-37.\n\n[YOUR_FULL_NAME]\n[YOUR_ADDRESS]"
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      draft_text,
      "fail", "pass", "pass", "pass"
    ])
    PolicyPost::SlmClient.default_client = client

    perform_enqueued_jobs do
      DraftGenerationJob.perform_later(draft.id)
    end

    draft.reload
    assert_equal "complete", draft.status
    assert_equal "pass_with_warning", draft.quality_status
    assert_not_empty draft.quality_warnings
  end

  test "handles SLM errors gracefully and completes" do
    draft = create_processing_draft

    # SLM client is exhausted — each module handles this internally
    client = PolicyPost::SlmClient::FakeSlmClient.new([])
    PolicyPost::SlmClient.default_client = client

    perform_enqueued_jobs do
      DraftGenerationJob.perform_later(draft.id)
    end

    draft.reload
    # The job should complete even when SLM is unreachable
    assert_equal "complete", draft.status
    assert draft.quality_status.present?
  end

  test "skips if draft is complete" do
    draft = email_drafts(:one)
    draft.update!(status: "complete", body: "Existing body")

    perform_enqueued_jobs do
      DraftGenerationJob.perform_later(draft.id)
    end

    draft.reload
    assert_equal "complete", draft.status
    assert_equal "Existing body", draft.body
  end

  test "skips if draft is not in processing status" do
    draft = email_drafts(:two)
    draft.update!(status: "pending", body: "Pending body")

    perform_enqueued_jobs do
      DraftGenerationJob.perform_later(draft.id)
    end

    draft.reload
    assert_equal "pending", draft.status
    assert_equal "Pending body", draft.body
  end
end
