require "test_helper"

class FederalAdapterTest < ActiveSupport::TestCase
  setup do
    @adapter = FederalAdapter.new
  end

  # --- normalize_status ---

  test "normalize_status maps 'At second reading in the House of Commons' to second_reading" do
    assert_equal "second_reading", @adapter.normalize_status("At second reading in the House of Commons")
  end

  test "normalize_status maps 'Second reading' to second_reading" do
    assert_equal "second_reading", @adapter.normalize_status("Second reading")
  end

  test "normalize_status maps 'Introduction and first reading' to introduced" do
    assert_equal "introduced", @adapter.normalize_status("Introduction and first reading")
  end

  test "normalize_status maps 'At consideration in committee' to committee" do
    assert_equal "committee", @adapter.normalize_status("At consideration in committee")
  end

  test "normalize_status maps 'At third reading' to third_reading" do
    assert_equal "third_reading", @adapter.normalize_status("At third reading")
  end

  test "normalize_status exact maps 'Royal Assent' to royal_assent" do
    assert_equal "royal_assent", @adapter.normalize_status("Royal Assent")
  end

  test "normalize_status exact maps 'Defeated' to defeated" do
    assert_equal "defeated", @adapter.normalize_status("Defeated")
  end

  test "normalize_status exact match takes precedence over substring" do
    assert_equal "royal_assent", @adapter.normalize_status("Royal Assent")
    assert_equal "defeated", @adapter.normalize_status("Defeated")
  end

  test "normalize_status defaults to introduced for unknown status" do
    assert_equal "introduced", @adapter.normalize_status("Some Unknown Status")
  end

  test "normalize_status defaults to introduced for blank status" do
    assert_equal "introduced", @adapter.normalize_status("")
    assert_equal "introduced", @adapter.normalize_status(nil)
  end

  # Real LEGISinfo CurrentStatusEn values (case-insensitive matching)

  test "normalize_status maps real 'Royal assent received' to royal_assent" do
    assert_equal "royal_assent", @adapter.normalize_status("Royal assent received")
  end

  test "normalize_status maps real 'Bill defeated' to defeated" do
    assert_equal "defeated", @adapter.normalize_status("Bill defeated")
  end

  test "normalize_status maps real 'Introduced as pro forma bill' to introduced" do
    assert_equal "introduced", @adapter.normalize_status("Introduced as pro forma bill")
  end

  test "normalize_status maps real 'Senate bill awaiting first reading in the House of Commons' to introduced" do
    assert_equal "introduced", @adapter.normalize_status("Senate bill awaiting first reading in the House of Commons")
  end

  test "normalize_status maps real 'Outside the Order of Precedence' to introduced" do
    assert_equal "introduced", @adapter.normalize_status("Outside the Order of Precedence")
  end

  # --- slugify_stage (private, tested via public interface) ---

  test "slugify_stage converts 'First reading' to 'first-reading'" do
    assert_equal "first-reading", @adapter.send(:slugify_stage, "First reading")
  end

  test "slugify_stage converts 'Second reading' to 'second-reading'" do
    assert_equal "second-reading", @adapter.send(:slugify_stage, "Second reading")
  end

  test "slugify_stage converts 'Third reading' to 'third-reading'" do
    assert_equal "third-reading", @adapter.send(:slugify_stage, "Third reading")
  end

  test "slugify_stage defaults to 'first-reading' for blank" do
    assert_equal "first-reading", @adapter.send(:slugify_stage, "")
    assert_equal "first-reading", @adapter.send(:slugify_stage, nil)
  end

  # --- ordinal (private) ---

  test "ordinal returns correct ordinals" do
    assert_equal "1st", @adapter.send(:ordinal, 1)
    assert_equal "2nd", @adapter.send(:ordinal, 2)
    assert_equal "3rd", @adapter.send(:ordinal, 3)
    assert_equal "4th", @adapter.send(:ordinal, 4)
    assert_equal "11th", @adapter.send(:ordinal, 11)
    assert_equal "12th", @adapter.send(:ordinal, 12)
    assert_equal "13th", @adapter.send(:ordinal, 13)
    assert_equal "21st", @adapter.send(:ordinal, 21)
    assert_equal "22nd", @adapter.send(:ordinal, 22)
    assert_equal "23rd", @adapter.send(:ordinal, 23)
    assert_equal "45th", @adapter.send(:ordinal, 45)
  end

  # --- parse_session (private) ---

  test "parse_session splits correctly" do
    assert_equal [ 45, 1 ], @adapter.send(:parse_session, "45-1")
    assert_equal [ 44, 2 ], @adapter.send(:parse_session, "44-2")
  end

  # --- parse_date (private) ---

  test "parse_date returns Date for valid date string" do
    result = @adapter.send(:parse_date, "2026-06-16T10:02:58.263")
    assert_equal Date.new(2026, 6, 16), result
  end

  test "parse_date returns nil for blank" do
    assert_nil @adapter.send(:parse_date, "")
    assert_nil @adapter.send(:parse_date, nil)
  end

  test "parse_date returns nil for invalid date" do
    assert_nil @adapter.send(:parse_date, "not-a-date")
  end

  # --- normalize_bill_type (private) ---

  test "normalize_bill_type maps 'House Government Bill' to government" do
    assert_equal "government", @adapter.send(:normalize_bill_type, "House Government Bill")
  end

  test "normalize_bill_type maps 'Senate Government Bill' to government" do
    assert_equal "government", @adapter.send(:normalize_bill_type, "Senate Government Bill")
  end

  test "normalize_bill_type maps curly-apostrophe PMB to private_member" do
    assert_equal "private_member", @adapter.send(:normalize_bill_type, "Private Member\u2019s Bill")
  end

  test "normalize_bill_type maps straight-apostrophe PMB to private_member" do
    assert_equal "private_member", @adapter.send(:normalize_bill_type, "Private Member's Bill")
  end

  test "normalize_bill_type maps 'Senate Public Bill' to senate_public" do
    assert_equal "senate_public", @adapter.send(:normalize_bill_type, "Senate Public Bill")
  end

  test "normalize_bill_type maps 'Senate Private Bill' to senate_private" do
    assert_equal "senate_private", @adapter.send(:normalize_bill_type, "Senate Private Bill")
  end

  test "normalize_bill_type returns nil for blank" do
    assert_nil @adapter.send(:normalize_bill_type, "")
    assert_nil @adapter.send(:normalize_bill_type, nil)
  end

  # --- chamber_name (private) ---

  test "chamber_name maps 1 to House of Commons" do
    assert_equal "House of Commons", @adapter.send(:chamber_name, FederalAdapter::HOUSE_OF_COMMONS_ID)
  end

  test "chamber_name maps 2 to Senate" do
    assert_equal "Senate", @adapter.send(:chamber_name, FederalAdapter::SENATE_ID)
  end

  test "chamber_name returns nil for unknown id" do
    assert_nil @adapter.send(:chamber_name, 99)
  end

  # --- extract_summary (private) ---

  test "extract_summary extracts text after SUMMARY heading" do
    html = <<~HTML
      <html><body>
        <h2>SUMMARY</h2>
        <p>This bill does something important.</p>
      </body></html>
    HTML
    doc = Nokogiri::HTML(html)
    assert_equal "This bill does something important.", @adapter.send(:extract_summary, doc)
  end

  test "extract_summary returns nil when no SUMMARY heading" do
    html = "<html><body><p>No summary here.</p></body></html>"
    doc = Nokogiri::HTML(html)
    assert_nil @adapter.send(:extract_summary, doc)
  end

  test "extract_summary collects multiple paragraphs until next h2" do
    html = <<~HTML
      <html><body>
        <h2>SUMMARY</h2>
        <p>First paragraph of summary.</p>
        <p>Second paragraph of summary.</p>
        <div>Third section in a div.</div>
        <h2>ANOTHER SECTION</h2>
        <p>This should not be included.</p>
      </body></html>
    HTML
    doc = Nokogiri::HTML(html)
    expected = "First paragraph of summary.\n\nSecond paragraph of summary.\n\nThird section in a div."
    assert_equal expected, @adapter.send(:extract_summary, doc)
  end

  test "extract_summary stops at next h2 and ignores trailing content" do
    html = <<~HTML
      <html><body>
        <h2>SUMMARY</h2>
        <p>Only this.</p>
        <h2>BODY</h2>
        <p>Not this.</p>
      </body></html>
    HTML
    doc = Nokogiri::HTML(html)
    assert_equal "Only this.", @adapter.send(:extract_summary, doc)
  end

  # --- extract_full_text (private) ---

  test "extract_full_text targets #flow-content when present" do
    html = <<~HTML
      <html><body>
        <div id="flow-content">Bill content here.</div>
        <div>Other content.</div>
      </body></html>
    HTML
    doc = Nokogiri::HTML(html)
    assert_equal "Bill content here.", @adapter.send(:extract_full_text, doc)
  end

  test "extract_full_text falls back to body when #flow-content not found" do
    html = <<~HTML
      <html><body>
        <p>Some body text.</p>
      </body></html>
    HTML
    doc = Nokogiri::HTML(html)
    assert_equal "Some body text.", @adapter.send(:extract_full_text, doc)
  end

  test "extract_full_text returns nil when no content" do
    html = "<html><body></body></html>"
    doc = Nokogiri::HTML(html)
    assert_nil @adapter.send(:extract_full_text, doc)
  end

  test "extract_full_text cleans up whitespace" do
    html = <<~HTML
      <html><body>
        <div id="flow-content">Word1   Word2


        Word3</div>
      </body></html>
    HTML
    doc = Nokogiri::HTML(html)
    result = @adapter.send(:extract_full_text, doc)
    assert_includes result, "Word1 Word2"
    refute_match(/\n{3,}/, result)
  end
end
