require "test_helper"

class PolicyPostDataPipelineClassificationTest < ActiveSupport::TestCase
  setup do
    @bill = bills(:one)
  end

  test "classification updates bill category from SLM response" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "indigenous" ])
    PolicyPost::SlmClient.default_client = client

    PolicyPost::DataPipeline::Classification.call(@bill)
    @bill.reload
    assert_equal "indigenous", @bill.category
  end

  test "classification strips whitespace and lowercases response" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "  DIGITAL  " ])
    PolicyPost::SlmClient.default_client = client

    PolicyPost::DataPipeline::Classification.call(@bill)
    @bill.reload
    assert_equal "digital", @bill.category
  end

  test "classification retries once on invalid category then falls back to governance" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "invalid_category", "also_invalid" ])
    PolicyPost::SlmClient.default_client = client

    PolicyPost::DataPipeline::Classification.call(@bill)
    @bill.reload
    assert_equal "governance", @bill.category
    assert_equal "Classification defaulted to governance after 2 SLM attempts", @bill.review_notes
  end

  test "classification fallback writes review_notes flag" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "bad_1", "bad_2" ])
    PolicyPost::SlmClient.default_client = client

    PolicyPost::DataPipeline::Classification.call(@bill)
    @bill.reload
    assert_equal "governance", @bill.category
    assert_not_nil @bill.review_notes
    assert_includes @bill.review_notes, "defaulted to governance"
  end

  test "classification succeeds on retry" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "invalid", "healthcare" ])
    PolicyPost::SlmClient.default_client = client

    PolicyPost::DataPipeline::Classification.call(@bill)
    @bill.reload
    assert_equal "healthcare", @bill.category
  end

  test "classification falls back to governance on error" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "  environment  " ])
    PolicyPost::SlmClient.default_client = client

    PolicyPost::DataPipeline::Classification.call(@bill)
    @bill.reload
    assert_equal "environment", @bill.category
  end

  test "classification never raises" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "also_bad_1", "also_bad_2" ])
    PolicyPost::SlmClient.default_client = client

    assert_nothing_raised do
      PolicyPost::DataPipeline::Classification.call(@bill)
    end
    @bill.reload
    assert_equal "governance", @bill.category
    assert_not_nil @bill.review_notes
  end
end
