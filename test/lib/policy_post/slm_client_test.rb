require "test_helper"

class PolicyPostSlmClientTest < ActiveSupport::TestCase
  test "SlmClient posts to chat completions endpoint" do
    responses = [ "governance" ]
    client = PolicyPost::SlmClient::FakeSlmClient.new(responses)
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::SlmClient.complete("test prompt", temperature: 0.3)
    assert_equal "governance", result
  end

  test "FakeSlmClient consumes responses sequentially" do
    responses = [ "first", "second", "third" ]
    client = PolicyPost::SlmClient::FakeSlmClient.new(responses)
    PolicyPost::SlmClient.default_client = client

    assert_equal "first", PolicyPost::SlmClient.complete("p1")
    assert_equal "second", PolicyPost::SlmClient.complete("p2")
    assert_equal "third", PolicyPost::SlmClient.complete("p3")
  end

  test "FakeSlmClient raises when exhausted" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([])
    PolicyPost::SlmClient.default_client = client

    assert_raises(RuntimeError) { PolicyPost::SlmClient.complete("prompt") }
  end

  test "SlmClient respects temperature parameter via client" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "ok" ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::SlmClient.complete("prompt", temperature: 0.3)
    assert_equal "ok", result
  end

  test "complete passes system prompt through client" do
    client = PolicyPost::SlmClient::FakeSlmClient.new([ "system ok" ])
    PolicyPost::SlmClient.default_client = client

    result = PolicyPost::SlmClient.complete("prompt", system: "You are helpful.")
    assert_equal "system ok", result
  end
end
