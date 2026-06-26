require "test_helper"

class PolicyPostDataPipelineQuestionGenerationTest < ActiveSupport::TestCase
  setup do
    @bill = bills(:one)
    @bill.update!(
      category: "governance",
      short_title: "Test Bill",
      title: "An Act to Test Generated Questions",
      summary: "This bill changes how tests are generated."
    )
    BillPhrase.create!(bill: @bill, phrase: "test generation", verified: true)
  end

  test "creates pending generated questions" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "How would this bill change the way test generation works for you?\nWhat part of the test generation process concerns you most?\nCan you share an example of how test generation has affected your work?"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionGeneration.call(@bill, position: "oppose")

    assert_equal 3, result.length
    assert result.all? { |q| q.is_a?(Question) }
    assert result.all? { |q| q.source == "generated" }
    assert result.all? { |q| q.status == "pending" }
    assert result.all? { |q| q.position == "oppose" }
    assert result.all? { |q| q.bill == @bill }
  end

  test "filters out questions not grounded in the bill" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "How would this bill change test generation?\nWhat do you think about politics in general?\nWhy is the sky blue?"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionGeneration.call(@bill, position: "oppose")

    assert_equal 1, result.length
    assert_includes result.first.body.downcase, "test generation"
  end

  test "filters out duplicates" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "How would this bill change test generation?\nHow would this bill change test generation?\nWhat part of test generation matters most?"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionGeneration.call(@bill, position: "oppose")

    assert_equal 2, result.length
  end

  test "does not create questions that duplicate templates" do
    template_body = Question.templates.active
      .for_category_and_position(@bill.category, "oppose")
      .first
      .body
      .gsub("{bill_subject}", @bill.short_title)

    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "#{template_body}\nWhat part of test generation matters most to you?"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionGeneration.call(@bill, position: "oppose")

    bodies = result.map(&:body)
    refute_includes bodies, template_body
    assert result.length >= 1
  end

  test "returns empty array and logs on error" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([])
    PolicyPost::SlmClient.default_client = client

    assert_nothing_raised do
      result = PolicyPost::DataPipeline::QuestionGeneration.call(@bill, position: "support")
      assert_empty result
    end
  end

  test "limits to max_count questions" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "How would this bill change test generation?\nWhat part matters most?\nCan you share an example?\nWhy do you care?\nWhat outcome do you want?"
    ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::DataPipeline::QuestionGeneration.call(@bill, position: "support")

    assert result.length <= PolicyPost::Config::QUESTION_GENERATION_CONFIG[:max_count]
  end
end
