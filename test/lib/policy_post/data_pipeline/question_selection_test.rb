require "test_helper"

class PolicyPostDataPipelineQuestionSelectionTest < ActiveSupport::TestCase
  setup do
    @bill = bills(:one)
  end

  test "question selection creates BillQuestionSelection records" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "1,2,3"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionSelection.call(@bill, position: "support")
    assert_equal 3, result.length
    assert result.all? { |s| s.is_a?(BillQuestionSelection) }
    assert result.all? { |s| s.position == "support" }
  end

  test "selects 2-3 questions" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "1,2,3"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionSelection.call(@bill, position: "support")
    assert_includes (2..3), result.length
  end

  test "retries once on invalid selection then falls back to rule-based" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "1,2",
      "1,2"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionSelection.call(@bill, position: "support")
    assert result.length >= 2
  end

  test "rule-based fallback sorts by priority and takes up to 3" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "99999,99999,99999",
      "99999,99999,99999"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionSelection.call(@bill, position: "support")
    assert result.length >= 2
    assert result.length <= 3
  end

  test "question selection never raises" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([])
    PolicyPost::SlmClient.default_client = client

    assert_nothing_raised do
      result = PolicyPost::DataPipeline::QuestionSelection.call(@bill, position: "support")
      assert result.is_a?(Array)
    end
  end

  test "selection works for oppose position" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "5,6,7"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionSelection.call(@bill, position: "oppose")
    assert result.length >= 2
    assert result.all? { |s| s.position == "oppose" }
  end

  test "requires 2 distinct question types" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "1,2,3"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionSelection.call(@bill, position: "support")
    types = result.map { |s| s.question.question_type }.uniq
    assert types.size >= 2, "Expected at least 2 distinct question types, got #{types.size}: #{types}"
  end

  test "prefers approved generated questions when available" do
    generated = Question.create!(
      bill: @bill,
      category: @bill.category,
      position: "support",
      question_type: "generated_specific",
      priority: 0,
      active: true,
      source: "generated",
      status: "approved",
      body: "How will this specific bill change access to services in your community?"
    )

    client = PolicyPost::SlmClient::FakeSlmClient.new([
      generated.id.to_s
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionSelection.call(@bill, position: "support")
    selected_ids = result.map(&:question_id)
    assert_includes selected_ids, generated.id
  end

  test "does not select pending or rejected generated questions" do
    pending = Question.create!(
      bill: @bill,
      category: @bill.category,
      position: "support",
      question_type: "generated_specific",
      priority: 0,
      active: true,
      source: "generated",
      status: "pending",
      body: "Pending question?"
    )

    rejected = Question.create!(
      bill: @bill,
      category: @bill.category,
      position: "support",
      question_type: "generated_specific",
      priority: 0,
      active: true,
      source: "generated",
      status: "rejected",
      body: "Rejected question?"
    )

    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "#{pending.id},#{rejected.id},1"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionSelection.call(@bill, position: "support")
    selected_ids = result.map(&:question_id)
    refute_includes selected_ids, pending.id
    refute_includes selected_ids, rejected.id
  end
end
