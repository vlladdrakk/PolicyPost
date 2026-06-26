require "test_helper"

class QuestionTest < ActiveSupport::TestCase
  setup do
    @bill = bills(:one)
  end

  test "template question is valid without bill" do
    question = Question.new(
      category: "governance",
      position: "support",
      question_type: "personal_impact",
      body: "How has {bill_subject} affected you?",
      source: "template",
      status: "approved"
    )
    assert question.valid?
  end

  test "generated question requires bill" do
    question = Question.new(
      category: "governance",
      position: "support",
      question_type: "generated",
      body: "How will this bill affect you?",
      source: "generated",
      status: "pending"
    )
    assert question.invalid?
    assert_includes question.errors[:bill_id], "is required for generated questions"
  end

  test "generated question with bill is valid" do
    question = Question.new(
      bill: @bill,
      category: "governance",
      position: "support",
      question_type: "generated",
      body: "How will this bill affect you?",
      source: "generated",
      status: "pending"
    )
    assert question.valid?
  end

  test "source must be template or generated" do
    question = questions(:indigenous_impact)
    question.source = "invalid"
    assert question.invalid?
    assert_includes question.errors[:source], "is not included in the list"
  end

  test "status must be pending, approved, or rejected" do
    question = questions(:indigenous_impact)
    question.status = "invalid"
    assert question.invalid?
    assert_includes question.errors[:status], "is not included in the list"
  end

  test "requires_bill_subject? detects placeholder" do
    assert questions(:indigenous_impact).requires_bill_subject?
  end

  test "generated? returns true for generated source" do
    question = Question.new(source: "generated")
    assert question.generated?

    question.source = "template"
    refute question.generated?
  end
end
