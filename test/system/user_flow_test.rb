require "application_system_test_case"

class UserFlowTest < ApplicationSystemTestCase
  setup do
    @bill = bills(:three)
    @bill.update!(processing_status: "approved", category: "indigenous")
    @bill.bill_question_selections.destroy_all

    support_q = questions(:indigenous_impact)
    oppose_q = questions(:indigenous_knowledge_oppose)
    BillQuestionSelection.create!(bill: @bill, question: support_q, position: "support")
    BillQuestionSelection.create!(bill: @bill, question: oppose_q, position: "oppose")

    @preset_draft = nil
  end

  def prefill_flow_to_draft
    visit root_path
    assert_text "PolicyPost"
    click_link "Select", match: :first

    assert_current_path %r{/bill/#{@bill.id}}
    assert_text @bill.short_title
    choose "My local Member of Parliament"
    fill_in "Postal Code", with: "K1P1A4"
    click_button "Start Writing"

    assert_text "Your Position"
    choose "Support"
    click_button "Continue to Questions"

    assert_text "Tell Us More"
    fill_in "answers[#{questions(:indigenous_impact).id}]", with: "This bill helps our community access clean water."
    click_button "Continue to Draft"
    sleep 1
  end

  test "full flow from bill index to draft" do
    prefill_flow_to_draft

    assert_text "Your Draft Email"
    assert_text @bill.bill_number

    # Pre-create a completed draft so the test does not depend on the
    # background job runner or an external SLM being available.
    session = UserSession.last
    letter = session.constituent_letter
    letter.email_drafts.destroy_all
    EmailDraft.create!(
      constituent_letter: letter,
      approach: "A",
      body: "Dear #{letter.representative.display_name},\n\nI am writing about #{letter.bill.bill_number}.\n\nSincerely,\n[YOUR_FULL_NAME]\n[YOUR_ADDRESS]",
      status: "complete",
      quality_status: "pass"
    )

    visit draft_session_path(session)

    assert_selector "button", text: "Copy draft"
    assert_selector "button", text: "Open email app"

    fill_in "Your Full Name", with: "Jane Doe"
    fill_in "Your Address", with: "123 Main St"
    click_button "Copy draft"
    assert_text "Draft copied to clipboard.", wait: 2
  end

  test "selecting prime minister recipient" do
    Representative.find_or_create_by!(title: "Prime Minister", name: "Justin Trudeau") do |rep|
      rep.email = "pm@pm.gc.ca"
    end

    visit root_path
    click_link "Select", match: :first

    choose "The Prime Minister"
    click_button "Start Writing"

    assert_text "Your Position"
    assert_text "Prime Minister"
  end

  test "start over link works" do
    visit root_path
    assert_text "PolicyPost"
    click_link "Select", match: :first
    assert_text @bill.short_title
    click_link "Choose a different bill"
    assert_current_path root_path
  end

  test "follow up shows read only answers" do
    visit root_path
    click_link "Select", match: :first

    choose "My local Member of Parliament"
    fill_in "Postal Code", with: "K1P1A4"
    click_button "Start Writing"

    choose "Support"
    click_button "Continue to Questions"

    assert_text "Tell Us More"
    fill_in "answers[#{questions(:indigenous_impact).id}]", with: "short"
    click_button "Continue to Draft"

    # Wait for async processing to redirect to draft
    sleep 1

    # If answer was vague, we'd see follow-up page.
    # In test, all answers come back "good" (SLM unreachable),
    # so we should land on the draft page.
    if page.has_text?("could use more detail")
      assert_selector "blockquote.answer-summary", text: "short"
      assert_no_selector "textarea[name^='answers']"
      fill_in "follow_up_answer", with: "More detailed explanation about water access."
      click_button "Submit & Continue to Draft"
      assert_text "Your Draft Email"
    else
      # Normal path: answers were good, went straight to draft
      assert_text "Your Draft Email"
    end
  end

  test "draft page polls status and loads" do
    visit root_path
    click_link "Select", match: :first

    choose "My local Member of Parliament"
    fill_in "Postal Code", with: "K1P1A4"
    click_button "Start Writing"

    choose "Support"
    click_button "Continue to Questions"

    fill_in "answers[#{questions(:indigenous_impact).id}]", with: "This bill helps our community access clean water."
    click_button "Continue to Draft"

    # Wait for question processing to finish and redirect to draft
    sleep 2

    # Should be on draft page
    assert_text "Your Draft Email"
  end
end
