require "test_helper"

class UserSessionTest < ActiveSupport::TestCase
  test "valid with postal_code and riding for local mp letter" do
    letter = constituent_letters(:one)
    session = UserSession.new(postal_code: "K1A0A6", riding: "Ottawa Centre", constituent_letter: letter)
    assert session.valid?
  end

  test "invalid without postal_code for local mp letter" do
    letter = constituent_letters(:one)
    session = UserSession.new(riding: "Ottawa Centre", constituent_letter: letter)
    assert_not session.valid?
  end

  test "invalid without riding for local mp letter" do
    letter = constituent_letters(:one)
    session = UserSession.new(postal_code: "K1A0A6", constituent_letter: letter)
    assert_not session.valid?
  end

  test "valid without postal_code or riding for prime minister letter" do
    letter = constituent_letters(:one)
    letter.update!(recipient_type: "prime_minister", postal_code: nil, riding: nil)
    session = UserSession.new(constituent_letter: letter)
    assert session.valid?
  end
end
