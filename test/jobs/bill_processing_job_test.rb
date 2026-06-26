require "test_helper"

class BillProcessingJobTest < ActiveJob::TestCase
  setup do
    @bill = bills(:one)
  end

  test "processes bill from pending through to review" do
    assert_equal "pending", @bill.processing_status

    classification_response = "indigenous"
    phrase_response = "First Nations water rights\nclean water access\nIndigenous jurisdiction"
    question_support_response = "1,2,3,4"
    question_oppose_response = "5,7,8,6"
    phrase_match_response = "Q1=P1,P2,P3\nQ2=P2,P1,P3"

    client = PolicyPost::SlmClient::FakeSlmClient.new([
      classification_response,
      phrase_response,
      question_support_response,
      phrase_match_response,
      question_oppose_response,
      phrase_match_response
    ])
    PolicyPost::SlmClient.default_client = client

    perform_enqueued_jobs do
      BillProcessingJob.perform_later(@bill.id)
    end

    @bill.reload
    assert_equal "review", @bill.processing_status
    assert_equal "indigenous", @bill.category
    assert @bill.bill_phrases.count.positive?, "Should have extracted phrases"
  end

  test "skips if status is not pending" do
    @bill.update!(processing_status: "approved")

    client = PolicyPost::SlmClient::FakeSlmClient.new([ "indigenous" ])
    PolicyPost::SlmClient.default_client = client

    perform_enqueued_jobs do
      BillProcessingJob.perform_later(@bill.id)
    end

    @bill.reload
    assert_equal "approved", @bill.processing_status
  end

  test "completes with fallbacks when SLM is unavailable" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([])
    PolicyPost::SlmClient.default_client = client

    perform_enqueued_jobs do
      BillProcessingJob.perform_later(@bill.id)
    end

    @bill.reload
    # All services fall back gracefully when SLM is unavailable
    assert_equal "review", @bill.processing_status
    assert_equal "governance", @bill.category
  end

  test "clears existing phrases, selections, and generated questions before processing" do
    BillPhrase.create!(bill: @bill, phrase: "old phrase")
    q = questions(:indigenous_impact)
    BillQuestionSelection.create!(bill: @bill, question: q, position: "support")
    Question.create!(
      bill: @bill, category: @bill.category, position: "support",
      question_type: "generated", source: "generated", status: "pending",
      body: "Old generated question?"
    )

    assert @bill.bill_phrases.count.positive?
    assert @bill.bill_question_selections.count.positive?
    assert @bill.generated_questions.generated.count.positive?

    classification_response = "indigenous"
    phrase_response = "First Nations water rights\nclean water access\nIndigenous jurisdiction"
    question_support_response = "1,2,3,4"
    question_oppose_response = "5,7,8,6"
    phrase_match_response = "Q1=P1,P2,P3\nQ2=P2,P1,P3"

    client = PolicyPost::SlmClient::FakeSlmClient.new([
      classification_response,
      phrase_response,
      question_support_response,
      phrase_match_response,
      question_oppose_response,
      phrase_match_response
    ])
    PolicyPost::SlmClient.default_client = client

    perform_enqueued_jobs do
      BillProcessingJob.perform_later(@bill.id)
    end

    @bill.reload
    assert @bill.bill_phrases.count.positive?, "Should have new phrases after cleanup"
    assert @bill.reload.bill_phrases.none? { |p| p.phrase == "old phrase" }, "Old phrases should be deleted"
    assert @bill.generated_questions.generated.none? { |q| q.body == "Old generated question?" },
           "Old generated questions should be deleted"
  end

  test "creates selections for both support and oppose positions" do
    classification_response = "indigenous"
    phrase_response = "First Nations water rights\nclean water access\nIndigenous jurisdiction"
    question_support_response = "1,2,3,4"
    question_oppose_response = "5,7,8,6"
    phrase_match_response = "Q1=P1,P2,P3\nQ2=P2,P1,P3"

    client = PolicyPost::SlmClient::FakeSlmClient.new([
      classification_response,
      phrase_response,
      question_support_response,
      phrase_match_response,
      question_oppose_response,
      phrase_match_response
    ])
    PolicyPost::SlmClient.default_client = client

    perform_enqueued_jobs do
      BillProcessingJob.perform_later(@bill.id)
    end

    @bill.reload
    support_selections = @bill.bill_question_selections.for_position("support")
    oppose_selections = @bill.bill_question_selections.for_position("oppose")
    assert support_selections.any?, "Should have support selections"
    assert oppose_selections.any?, "Should have oppose selections"
  end
end
