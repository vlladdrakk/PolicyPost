require "test_helper"

class BillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bill = bills(:three)
    @bill.update!(processing_status: "approved", category: "indigenous")
  end

  test "index lists approved bills" do
    get root_path
    assert_response :success
    assert_select "h1", "PolicyPost"
    assert_select "a[href=?]", bill_path(@bill)
  end

  test "show displays bill and recipient options" do
    get bill_path(@bill)
    assert_response :success
    assert_select "h1", /#{@bill.bill_number}/
    assert_select "input[name=recipient_type]"
    assert_select "a[href=?]", @bill.source_url, text: /View original bill/
  end
end
