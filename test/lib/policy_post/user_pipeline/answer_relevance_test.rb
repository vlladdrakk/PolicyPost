require "test_helper"

class PolicyPostUserPipelineAnswerRelevanceTest < ActiveSupport::TestCase
  test "returns good for specific answer" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "good" ])
    result = PolicyPost::UserPipeline::AnswerRelevance.check(
      question: "Test question?", answer: "This bill helped our community.", slm_client: client
    )
    assert_equal "good", result[:verdict]
    assert_nil result[:follow_up]
  end

  test "returns vague with follow_up" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "vague", "3" ])
    result = PolicyPost::UserPipeline::AnswerRelevance.check(
      question: "Test question?", answer: "it's good", slm_client: client
    )
    assert_equal "vague", result[:verdict]
    assert_equal "Who else is affected by this that you know of?", result[:follow_up]
  end

  test "invalid verdict falls back to good" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "whatever" ])
    result = PolicyPost::UserPipeline::AnswerRelevance.check(
      question: "Test question?", answer: "some answer", slm_client: client
    )
    assert_equal "good", result[:verdict]
    assert_nil result[:follow_up]
  end

  test "blank answer returns good" do
    result = PolicyPost::UserPipeline::AnswerRelevance.check(question: "Q?", answer: "")
    assert_equal "good", result[:verdict]
    assert_nil result[:follow_up]
  end

  test "i_dont_know returns good" do
    result = PolicyPost::UserPipeline::AnswerRelevance.check(question: "Q?", answer: "I don't know")
    assert_equal "good", result[:verdict]
    assert_nil result[:follow_up]
  end

  test "follow_up selection falls back to default on invalid number" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "vague", "99" ])
    result = PolicyPost::UserPipeline::AnswerRelevance.check(
      question: "Test question?", answer: "vague answer", slm_client: client
    )
    assert_equal "vague", result[:verdict]
    assert_equal "Can you give a specific example?", result[:follow_up]
  end

  test "never raises on error" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([])
    result = PolicyPost::UserPipeline::AnswerRelevance.check(question: "Q?", answer: "test", slm_client: client)
    assert_equal "good", result[:verdict]
  end
end
