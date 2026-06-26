require "test_helper"

class PolicyPostDataPipelinePhraseMatchingTest < ActiveSupport::TestCase
  setup do
    @bill = bills(:one)
    @phrases = [
      BillPhrase.create!(bill: @bill, phrase: "First Nations water rights", verified: true),
      BillPhrase.create!(bill: @bill, phrase: "clean water access", verified: true),
      BillPhrase.create!(bill: @bill, phrase: "Indigenous jurisdiction", verified: true)
    ]

    q1 = questions(:indigenous_impact)
    q2 = questions(:indigenous_knowledge)

    @sel1 = BillQuestionSelection.create!(bill: @bill, question: q1, position: "support")
    @sel2 = BillQuestionSelection.create!(bill: @bill, question: q2, position: "support")
  end

  test "creates QuestionPhrase records for bill_subject questions" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "Q1=P1,P2,P3\nQ2=P2,P1,P3"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::PhraseMatching.call(
      @bill, phrases: @phrases, selections: [ @sel1, @sel2 ]
    )
    assert result.length >= 3
    assert result.all? { |qp| qp.is_a?(QuestionPhrase) }
  end

  test "assigns rank 1, 2, 3 to matched phrases" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "Q1=P1,P2,P3"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::PhraseMatching.call(
      @bill, phrases: @phrases, selections: [ @sel1 ]
    )
    assert_equal 3, result.length
    ranks = result.map(&:rank).sort
    assert_equal [ 1, 2, 3 ], ranks
  end

  test "skips questions without bill_subject" do
    values_q = questions(:indigenous_values)
    values_sel = BillQuestionSelection.create!(bill: @bill, question: values_q, position: "oppose")

    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "Q1=P1,P2,P3"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::PhraseMatching.call(
      @bill, phrases: @phrases, selections: [ @sel1, values_sel ]
    )
    assert result.all? { |qp| qp.bill_question_selection_id != values_sel.id }
  end

  test "fills missing with short_title when fewer than 3 valid phrase matches" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "Q1=P1,P2\nQ2=P1"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::PhraseMatching.call(
      @bill, phrases: @phrases, selections: [ @sel1, @sel2 ]
    )
    assert result.any?, "Should have some phrase matches"
  end

  test "parse failure assigns top 3 phrases to every question" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "garbage output not parsable at all"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::PhraseMatching.call(
      @bill, phrases: @phrases, selections: [ @sel1, @sel2 ]
    )
    assert result.any?
  end

  test "phrase matching never raises" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([])
    PolicyPost::SlmClient.default_client = client

    assert_nothing_raised do
      result = PolicyPost::DataPipeline::PhraseMatching.call(
        @bill, phrases: @phrases, selections: [ @sel1 ]
      )
      assert result.is_a?(Array)
    end
  end

  test "returns empty array when no selections require bill_subject" do
    values_q = questions(:indigenous_values)
    values_sel = BillQuestionSelection.create!(bill: @bill, question: values_q, position: "oppose")

    result = PolicyPost::DataPipeline::PhraseMatching.call(
      @bill, phrases: @phrases, selections: [ values_sel ]
    )
    assert_equal [], result
  end

  # --- reassign tests (programmatic, no SLM) ---

  test "reassign creates QuestionPhrase records for bill_subject questions" do
    PolicyPost::DataPipeline::PhraseMatching.reassign(@bill)

    assert @sel1.question_phrases.count > 0, "Expected question_phrases for sel1"
    assert @sel2.question_phrases.count > 0, "Expected question_phrases for sel2"
  end

  test "reassign assigns ranks 1, 2, 3" do
    PolicyPost::DataPipeline::PhraseMatching.reassign(@bill)

    ranks = @sel1.question_phrases.pluck(:rank).sort
    assert_equal [ 1, 2, 3 ], ranks
  end

  test "reassign skips questions without bill_subject" do
    values_q = questions(:indigenous_values)
    values_sel = BillQuestionSelection.create!(bill: @bill, question: values_q, position: "oppose")

    PolicyPost::DataPipeline::PhraseMatching.reassign(@bill)

    assert_equal 0, values_sel.question_phrases.count
  end

  test "reassign handles zero verified phrases" do
    @bill.bill_phrases.destroy_all
    result = PolicyPost::DataPipeline::PhraseMatching.reassign(@bill)
    assert_equal true, result
  end

  test "reassign handles fewer than 3 verified phrases" do
    @bill.bill_phrases.destroy_all
    BillPhrase.create!(bill: @bill, phrase: "test phrase one", verified: true)
    BillPhrase.create!(bill: @bill, phrase: "water rights", verified: true)
    @bill.reload
    PolicyPost::DataPipeline::PhraseMatching.reassign(@bill)
    count = @sel1.question_phrases.count
    assert_equal 2, count, "Expected 2 phrases, got #{count}"
  end

  test "reassign returns true on success" do
    result = PolicyPost::DataPipeline::PhraseMatching.reassign(@bill)
    assert_equal true, result
  end
end
