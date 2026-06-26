require "application_system_test_case"

class ReviewBillsTest < ApplicationSystemTestCase
  setup do
    @bill = bills(:one)
    @bill.update!(processing_status: "review", category: "indigenous", review_notes: nil)
    @bill.bill_phrases.destroy_all
    @bill.bill_question_selections.destroy_all

    @phrase = BillPhrase.create!(bill: @bill, phrase: "clean drinking water", verified: true)

    support_q = questions(:indigenous_impact)
    oppose_q = questions(:indigenous_knowledge_oppose)
    @sel1 = BillQuestionSelection.create!(bill: @bill, question: support_q, position: "support")
    @sel2 = BillQuestionSelection.create!(bill: @bill, question: oppose_q, position: "oppose")
  end

  test "visiting review index" do
    visit admin_bills_path
    assert_selector "h1", text: "Bill Review"
    assert_text @bill.bill_number
  end

  test "visiting review show page" do
    visit admin_bill_path(@bill)
    assert_text @bill.short_title
    assert_text "clean drinking water"
  end

  test "approving a bill" do
    visit admin_bill_path(@bill)
    click_button "Approve Bill"
    assert_current_path admin_bills_path
    fresh = Bill.find(@bill.id)
    assert_equal "approved", fresh.processing_status
  end

  test "rejecting a bill with reason" do
    visit admin_bill_path(@bill)
    fill_in "bill_review_notes", with: "Wrong category"
    click_button "Reject Bill"
    sleep 0.5
    fresh = Bill.find(@bill.id)
    assert_equal "rejected", fresh.processing_status, "Expected rejected but was #{fresh.processing_status}"
    assert_equal "Wrong category", fresh.review_notes
  end

  test "rejecting with blank reason shows error" do
    visit admin_bill_path(@bill)
    click_button "Reject Bill"
    assert_text "rejection reason is required"
    fresh = Bill.find(@bill.id)
    assert_equal "review", fresh.processing_status
  end

  test "changing category" do
    visit admin_bill_path(@bill)
    select "healthcare", from: "bill_category"
    click_button "Update Category"
    assert_current_path admin_bill_path(@bill)
    assert_text "Category updated"
    fresh = Bill.find(@bill.id)
    assert_equal "healthcare", fresh.category
  end

  test "adding a phrase" do
    visit admin_bill_path(@bill)
    fill_in "phrase", with: "water rights"
    click_button "Add"
    assert_text "water rights"
    assert Bill.find(@bill.id).bill_phrases.verified.exists?(phrase: "water rights")
  end

  test "removing a phrase" do
    visit admin_bill_path(@bill)
    assert_text "clean drinking water"
    first("a", text: "Remove").click
    assert_no_text "clean drinking water", wait: 5
    assert_not Bill.find(@bill.id).bill_phrases.verified.exists?(phrase: "clean drinking water")
  end

  test "adding a question" do
    visit admin_bill_path(@bill)
    first("select[name='question_id']").select "What personal experience do you have with"
    first("input[value='Add Question']").click
    assert_text "Question added", wait: 5
    assert Bill.find(@bill.id).bill_question_selections.count > 2
  end

  test "removing a question" do
    initial_count = @bill.bill_question_selections.count
    visit admin_bill_path(@bill)
    all("a", text: "Remove").last.click
    assert_text "Question removed", wait: 5
    assert Bill.find(@bill.id).bill_question_selections.count < initial_count
  end

  test "fallback warning shown when classification defaulted" do
    bill = Bill.find(@bill.id)
    bill.update!(review_notes: "Classification defaulted to governance after 2 SLM attempts")
    visit admin_bill_path(bill)
    assert_text "defaulted to governance"
  end

  test "pending generated questions block approval" do
    Question.create!(
      bill: @bill,
      category: @bill.category,
      position: "support",
      question_type: "generated",
      source: "generated",
      status: "pending",
      body: "Pending generated question?"
    )

    visit admin_bill_path(@bill)
    click_button "Approve Bill"
    assert_text "All generated questions must be approved or rejected"
    assert_equal "review", Bill.find(@bill.id).processing_status
  end

  test "approving a generated question adds it to selections" do
    generated = Question.create!(
      bill: @bill,
      category: @bill.category,
      position: "support",
      question_type: "generated",
      source: "generated",
      status: "pending",
      body: "How will this bill affect your community specifically?"
    )

    visit admin_bill_path(@bill)
    within("#generated_question_#{generated.id}") do
      click_button "Approve"
    end

    assert_text "Generated question approved"
    assert_text "How will this bill affect your community specifically?", wait: 5
    assert Bill.find(@bill.id).bill_question_selections.exists?(question_id: generated.id)
  end

  test "rejecting a generated question keeps it visible" do
    generated = Question.create!(
      bill: @bill,
      category: @bill.category,
      position: "oppose",
      question_type: "generated",
      source: "generated",
      status: "pending",
      body: "Rejected question?"
    )

    visit admin_bill_path(@bill)
    within("#generated_question_#{generated.id}") do
      click_button "Reject"
    end

    assert_text "Generated question rejected"
    assert_equal "rejected", Question.find(generated.id).status
    visit admin_bill_path(@bill)
    assert_text "Rejected question?"
  end

  test "reprocessing a bill" do
    visit admin_bill_path(@bill)
    accept_confirm { click_button "Reprocess Bill" }
    assert_current_path admin_bills_path(status: "all")
    assert_text "queued for reprocessing"
    fresh = Bill.find(@bill.id)
    assert_equal "pending", fresh.processing_status
    assert_nil fresh.review_notes
  end

  test "senate filter on index" do
    senate_bill = bills(:senate)
    bill_two = bills(:two)

    visit admin_bills_path(status: "all")

    # Senate bill should be visible
    assert_text senate_bill.bill_number
    assert_text bill_two.bill_number

    # Check the exclude checkbox — onchange auto-submits the form
    check "Exclude Senate bills"

    # Senate bill should be hidden
    assert_no_text senate_bill.bill_number
    assert_text bill_two.bill_number
  end

  test "reset all resets all bills" do
    approved_bill = bills(:senate)
    approved_bill.update!(processing_status: "approved")

    visit admin_bills_path(status: "all")
    accept_confirm { click_button "Reset All Bills" }

    assert_text "queued for reprocessing"

    Bill.find_each do |bill|
      assert_equal "pending", bill.reload.processing_status
    end
  end
end
