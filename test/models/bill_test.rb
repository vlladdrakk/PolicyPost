require "test_helper"

class BillTest < ActiveSupport::TestCase
  test "valid bill with all required fields" do
    bill = bills(:one)
    assert bill.valid?
  end

  test "valid bill without summary" do
    bill = bills(:two)
    assert_nil bill.summary
    assert bill.valid?
  end

  test "valid bill without full_text_url" do
    bill = bills(:one)
    bill.full_text_url = nil
    assert bill.valid?
  end

  test "invalid without jurisdiction" do
    bill = bills(:one)
    bill.jurisdiction = nil
    assert_not bill.valid?
    assert_includes bill.errors[:jurisdiction], "can't be blank"
  end

  test "invalid without title" do
    bill = bills(:one)
    bill.title = nil
    assert_not bill.valid?
    assert_includes bill.errors[:title], "can't be blank"
  end

  test "invalid without source_bill_id" do
    bill = bills(:one)
    bill.source_bill_id = nil
    assert_not bill.valid?
    assert_includes bill.errors[:source_bill_id], "can't be blank"
  end

  test "invalid with duplicate source_bill_id" do
    bill = bills(:two)
    bill.source_bill_id = bills(:one).source_bill_id
    assert_not bill.valid?
    assert_includes bill.errors[:source_bill_id], "has already been taken"
  end

  test "invalid with bad category" do
    bill = bills(:one)
    bill.category = "invalid_category"
    assert_not bill.valid?
    assert_includes bill.errors[:category], "is not included in the list"
  end

  test "invalid with bad status" do
    bill = bills(:one)
    bill.status = "invalid_status"
    assert_not bill.valid?
    assert_includes bill.errors[:status], "is not included in the list"
  end

  test "approved scope returns only approved bills" do
    bills(:one).update!(processing_status: "approved")
    bills(:two).update!(processing_status: "pending")

    assert_includes Bill.approved, bills(:one)
    assert_not_includes Bill.approved, bills(:two)
  end

  test "for_jurisdiction scope filters by jurisdiction" do
    bills(:one).update!(jurisdiction: "federal")
    bills(:two).update!(jurisdiction: "on")
    bills(:three).update!(jurisdiction: "on")
    bills(:senate).update!(jurisdiction: "on")

    assert_equal 1, Bill.for_jurisdiction("federal").count
    assert_includes Bill.for_jurisdiction("federal"), bills(:one)
  end

  test "create_from_raw creates bill from RawBill" do
    raw = RawBill.new(
      jurisdiction: "federal",
      legislature_session: "45th Parliament, 1st Session",
      bill_number: "C-99",
      bill_type: "Private Member's Bill",
      title: "Test Bill Title",
      short_title: "Test Act",
      summary: "A test bill.",
      sponsor_name: "Jane Doe",
      sponsor_riding: "Test Riding",
      sponsor_party: nil,
      status: "introduced",
      introduced_date: Date.new(2026, 6, 1),
      last_updated_date: Date.new(2026, 6, 1),
      full_text_url: "https://example.com/bill",
      full_text: "Full text of the bill.",
      source_url: "https://example.com/source",
      source_id: "99999999",
      source_bill_id: 99999999,
      parliament_number: 45,
      session_number: 1,
      is_government_bill: false,
      originating_chamber: "House of Commons"
    )

    bill = Bill.create_from_raw(raw)
    assert bill.persisted?
    assert_equal "federal", bill.jurisdiction
    assert_equal "C-99", bill.bill_number
    assert_equal "introduced", bill.status
    assert_equal 99999999, bill.source_bill_id
    assert_equal 45, bill.parliament_number
    assert_equal 1, bill.session_number
    assert_equal false, bill.is_government_bill
    assert_equal "House of Commons", bill.originating_chamber
  end

  test "approve! transitions from review to approved" do
    bill = bills(:one)
    bill.update!(processing_status: "review")
    bill.approve!
    assert_equal "approved", bill.processing_status
  end

  test "approve! raises when not in review" do
    bill = bills(:one)
    bill.update!(processing_status: "pending")
    assert_raises(ActiveRecord::RecordInvalid) { bill.approve! }
  end

  test "reject! with reason transitions from review to rejected" do
    bill = bills(:one)
    bill.update!(processing_status: "review")
    bill.reject!(reason: "Category is wrong")
    assert_equal "rejected", bill.processing_status
    assert_equal "Category is wrong", bill.review_notes
  end

  test "reject! with blank reason raises" do
    bill = bills(:one)
    bill.update!(processing_status: "review")
    assert_raises(ArgumentError) { bill.reject!(reason: "") }
  end

  test "reject! raises when not in review" do
    bill = bills(:one)
    bill.update!(processing_status: "approved")
    assert_raises(ActiveRecord::RecordInvalid) { bill.reject!(reason: "test") }
  end

  test "senate_bill? returns true for Senate-originated bill" do
    bill = bills(:senate)
    assert bill.senate_bill?
  end

  test "senate_bill? returns false for House-originated bill" do
    bill = bills(:one)
    assert_not bill.senate_bill?
  end

  test "senate_bill? returns false when originating_chamber is nil" do
    bill = bills(:one)
    bill.originating_chamber = nil
    assert_not bill.senate_bill?
  end
end
