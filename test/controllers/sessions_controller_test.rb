require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bill = bills(:three)
    @bill.update!(processing_status: "approved")
    @postal = postal_codes(:one)
  end

  test "create with local mp recipient redirects to position page" do
    post sessions_path, params: {
      bill_id: @bill.id,
      recipient_type: "local_mp",
      postal_code: @postal.code
    }

    assert_redirected_to %r{/session/\d+/position}
    session = UserSession.last
    assert_equal @postal.code, session.postal_code
    assert_equal "local_mp", session.constituent_letter.recipient_type
  end

  test "create with prime minister recipient redirects to position page" do
    Representative.find_or_create_by!(title: "Prime Minister", name: "Justin Trudeau") do |rep|
      rep.email = "pm@pm.gc.ca"
    end

    post sessions_path, params: {
      bill_id: @bill.id,
      recipient_type: "prime_minister"
    }

    assert_redirected_to %r{/session/\d+/position}
    session = UserSession.last
    assert_equal "prime_minister", session.constituent_letter.recipient_type
    assert_nil session.postal_code
  end

  test "create with cabinet minister recipient requires minister_id" do
    minister = representatives(:one)
    minister.update!(is_minister: true)

    post sessions_path, params: {
      bill_id: @bill.id,
      recipient_type: "cabinet_minister",
      minister_id: minister.id
    }

    assert_redirected_to %r{/session/\d+/position}
    session = UserSession.last
    assert_equal "cabinet_minister", session.constituent_letter.recipient_type
    assert_equal minister, session.constituent_letter.representative
  end

  test "create with invalid recipient type redirects back to bill" do
    post sessions_path, params: {
      bill_id: @bill.id,
      recipient_type: "invalid"
    }

    assert_redirected_to bill_path(@bill)
  end
end
