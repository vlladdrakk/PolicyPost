require "test_helper"

class PolicyPostUserPipelineEmailDraftingTest < ActiveSupport::TestCase
  test "generates draft from slm response" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "Dear MP,\n\nI am writing as a constituent regarding Bill C-37.\n\nSincerely,\n[YOUR_FULL_NAME]\n[YOUR_ADDRESS]"
    ])
    letter = constituent_letters(:one)
    result = PolicyPost::UserPipeline::EmailDrafting.draft(letter, slm_client: client)
    assert result.is_a?(String)
    assert result.length > 10
  end

  test "generates draft for senate bill with bill_origin context" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "Dear MP,\n\nI am writing as a constituent regarding Bill S-229, introduced in the Senate.\n\nSincerely,\n[YOUR_FULL_NAME]\n[YOUR_ADDRESS]"
    ])
    letter = constituent_letters(:senate)
    result = PolicyPost::UserPipeline::EmailDrafting.draft(letter, slm_client: client)
    assert result.is_a?(String)
    assert result.length > 10
    assert result.include?("S-229")
  end

  test "handles slm error gracefully" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([])
    letter = constituent_letters(:one)
    result = PolicyPost::UserPipeline::EmailDrafting.draft(letter, slm_client: client)
    assert result.is_a?(String)
  end
end
