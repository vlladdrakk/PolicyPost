require "test_helper"

class PolicyPostUserPipelineQualityChecksTest < ActiveSupport::TestCase
  test "returns an EmailQualityReport" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "pass", "pass", "pass", "pass"
    ])
    letter = constituent_letters(:one)
    email = "Dear MP,\n\nThis email is about bill C-37 which I support.\n\n[YOUR_FULL_NAME]\n[YOUR_ADDRESS]"
    result = PolicyPost::UserPipeline::QualityChecks.run(email_text: email, letter: letter, slm_client: client)
    assert result.is_a?(PolicyPost::EmailQuality::EmailQualityReport)
    assert_includes %w[pass pass_with_warning show_with_warnings], result.status
  end

  test "detects when checks fail" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([
      "fail", "fail", "fail", "fail"
    ])
    letter = constituent_letters(:one)
    email = "Bad email with no content"
    result = PolicyPost::UserPipeline::QualityChecks.run(email_text: email, letter: letter, slm_client: client)
    assert result.is_a?(PolicyPost::EmailQuality::EmailQualityReport)
  end

  test "handles error gracefully" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([])
    letter = constituent_letters(:one)
    email = "test email content"
    result = PolicyPost::UserPipeline::QualityChecks.run(email_text: email, letter: letter, slm_client: client)
    assert result.is_a?(PolicyPost::EmailQuality::EmailQualityReport)
  end
end
