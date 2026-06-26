#!/usr/bin/env ruby
# frozen_string_literal: true

# Integration test for the FederalAdapter against the live LEGISinfo API.
#
# Usage:
#   bin/rails runner scripts/test_federal_adapter.rb
#
# Env vars (must be exported BEFORE bin/rails):
#   OFFLINE=1       Skip all network tests; only run offline checks.
#   SESSION=45-1    Parliament-session string to test against (default 45-1).
#   LIMIT=3         Number of bills to fully fetch & verify (default 3).
#   SINCE_DAYS=30   Fetch_new_bills window in days (default 30).
#
# Examples:
#   OFFLINE=1 bin/rails runner scripts/test_federal_adapter.rb
#   SESSION=45-1 LIMIT=5 bin/rails runner scripts/test_federal_adapter.rb

require "net/http"
require "uri"
require "json"
require "date"
require "nokogiri"

# ──────────────────────────────────────────────────────────────
# Mini test framework
# ──────────────────────────────────────────────────────────────

module AdapterTest
  ANSI = {
    reset: "\e[0m", bold: "\e[1m",
    green: "\e[32m", red: "\e[31m", yellow: "\e[33m",
    cyan: "\e[36m", gray: "\e[90m"
  }.freeze

  PASS = "[PASS]"
  FAILLABEL = "[FAIL]"
  SKIPLABEL = "[SKIP]"
  INFOLABEL = "[INFO]"

  @results = { pass: 0, fail: 0, skip: 0 }

  class << self
    attr_accessor :results
  end

  def self.color(code, str)
    return str unless $stdout.tty?

    "#{ANSI[code]}#{str}#{ANSI[:reset]}"
  end

  def self.check(label, condition, details = nil)
    status = condition ? PASS : FAILLABEL
    results[:pass] += 1 if condition
    results[:fail] += 1 unless condition
    puts "#{color(condition ? :green : :red, status)} #{label}"
    if details
      col = condition ? :gray : :red
      puts "     #{color(col, details)}"
    end
  end

  def self.info(label, value)
    puts "#{color(:cyan, INFOLABEL)} #{label}: #{value}"
  end

  def self.skip(label, reason)
    results[:skip] += 1
    puts "#{color(:yellow, SKIPLABEL)} #{label} \u2014 #{reason}"
  end

  def self.section(title)
    puts "\n#{color(:bold, "== #{title} ==")}\n"
  end

  def self.print_summary
    section("Summary")
    total = results.values.sum
    puts "Total:  #{total}"
    puts color(:green, "  Pass:  #{results[:pass]}")
    puts color(:red, "  Fail:  #{results[:fail]}")
    puts color(:yellow, "  Skip:  #{results[:skip]}")
    exit(results[:fail].positive? ? 1 : 0)
  end

  def self.field_present?(raw, attr, required: true)
    value = raw.send(attr)
    present = !value.nil? && (value.is_a?(String) ? !value.strip.empty? : true)
    if required
      check("  #{attr}", present, "value=#{value.inspect[0, 100]}")
    elsif present
      check("  #{attr}", true, "value=#{value.inspect[0, 100]}")
    else
      skip("  #{attr}", "optional, not present")
    end
  end
end

# ──────────────────────────────────────────────────────────────
# Setup
# ──────────────────────────────────────────────────────────────

AdapterTest.section("Setup")

SESSION = ENV.fetch("SESSION", "45-1")
LIMIT = ENV.fetch("LIMIT", "3").to_i
SINCE_DAYS = ENV.fetch("SINCE_DAYS", "30").to_i
OFFLINE = ENV["OFFLINE"].present?

adapter = FederalAdapter.new

AdapterTest.info("Session", SESSION)
AdapterTest.info("Bill limit", LIMIT)
AdapterTest.info("Since days", SINCE_DAYS)
AdapterTest.info("Offline mode", OFFLINE ? "yes" : "no")

# ──────────────────────────────────────────────────────────────
# 1. normalize_status (offline, no network)
# ──────────────────────────────────────────────────────────────

AdapterTest.section("normalize_status (offline)")

status_cases = [
  # [input, expected]
  [ "At second reading in the House of Commons", "second_reading" ],
  [ "Second reading",                            "second_reading" ],
  [ "Introduction and first reading",            "introduced" ],
  [ "At consideration in committee",             "committee" ],
  [ "At report stage in the House of Commons",   "committee" ],
  [ "At third reading in the Senate",            "third_reading" ],
  [ "Royal Assent",                              "royal_assent" ],
  [ "Royal assent received",                     "royal_assent" ],
  [ "Defeated",                                  "defeated" ],
  [ "Bill defeated",                             "defeated" ],
  [ "Introduced as pro forma bill",              "introduced" ],
  [ "Senate bill awaiting first reading in the House of Commons", "introduced" ],
  [ "Outside the Order of Precedence",          "introduced" ],
  [ "Some Unknown Status",                      "introduced" ],
  [ "",                                          "introduced" ],
  [ nil,                                         "introduced" ]
]

status_cases.each do |input, expected|
  result = adapter.normalize_status(input)
  AdapterTest.check("'#{input}' \u2192 '#{expected}'", result == expected, "got '#{result}'")
end

# ──────────────────────────────────────────────────────────────
# 2. Private helpers (offline)
# ──────────────────────────────────────────────────────────────

AdapterTest.section("private helpers (offline)")

# slugify_stage
slug_cases = [
  [ "First reading",  "first-reading" ],
  [ "Second reading", "second-reading" ],
  [ "Third reading",  "third-reading" ],
  [ "Royal assent",   "royal-assent" ],
  [ "",               "first-reading" ],
  [ nil,              "first-reading" ]
]
slug_cases.each do |input, expected|
  result = adapter.send(:slugify_stage, input)
  AdapterTest.check("slugify_stage('#{input}') \u2192 '#{expected}'", result == expected, "got '#{result}'")
end

# parse_session
ps_result = adapter.send(:parse_session, "45-1")
AdapterTest.check("parse_session('45-1') \u2192 [45, 1]", ps_result == [ 45, 1 ], "got #{ps_result.inspect}")

# ordinal
ordinal_cases = [ [ 1, "1st" ], [ 2, "2nd" ], [ 3, "3rd" ], [ 11, "11th" ], [ 45, "45th" ] ]
ordinal_cases.each do |n, expected|
  result = adapter.send(:ordinal, n)
  AdapterTest.check("ordinal(#{n}) \u2192 '#{expected}'", result == expected, "got '#{result}'")
end

# parse_date
pd_result = adapter.send(:parse_date, "2026-06-16T10:02:58.263")
AdapterTest.check("parse_date returns Date", pd_result == Date.new(2026, 6, 16), "got #{pd_result.inspect}")
AdapterTest.check("parse_date nil for blank", adapter.send(:parse_date, nil).nil?)
AdapterTest.check("parse_date nil for invalid", adapter.send(:parse_date, "garbage").nil?)

# normalize_bill_type
btype_cases = [
  [ "House Government Bill", "government" ],
  [ "Senate Government Bill", "government" ],
  [ "Private Member\u2019s Bill", "private_member" ],
  [ "Private Member's Bill",  "private_member" ],
  [ "Senate Public Bill",     "senate_public" ],
  [ "Senate Private Bill",    "senate_private" ]
]
btype_cases.each do |input, expected|
  result = adapter.send(:normalize_bill_type, input)
  AdapterTest.check("normalize_bill_type('#{input}') \u2192 '#{expected}'", result == expected, "got '#{result}'")
end
AdapterTest.check("normalize_bill_type nil for blank", adapter.send(:normalize_bill_type, nil).nil?)

# chamber_name
AdapterTest.check("chamber_name(1) \u2192 'House of Commons'",
  adapter.send(:chamber_name, 1) == "House of Commons")
AdapterTest.check("chamber_name(2) \u2192 'Senate'",
  adapter.send(:chamber_name, 2) == "Senate")
AdapterTest.check("chamber_name(99) \u2192 nil",
  adapter.send(:chamber_name, 99).nil?)

# extract_summary
summary_html = <<~HTML
  <html><body>
    <h2>SUMMARY</h2>
    <p>First paragraph.</p>
    <p>Second paragraph.</p>
    <h2>ANOTHER</h2>
    <p>Not included.</p>
  </body></html>
HTML
summary_doc = Nokogiri::HTML(summary_html)
summary_result = adapter.send(:extract_summary, summary_doc)
AdapterTest.check(
  "extract_summary collects multiple paragraphs",
  summary_result == "First paragraph.\n\nSecond paragraph.",
  "got: #{summary_result.inspect}"
)
AdapterTest.check(
  "extract_summary returns nil when no SUMMARY heading",
  adapter.send(:extract_summary, Nokogiri::HTML("<html><body><p>Nope</p></body></html>")).nil?
)

# extract_full_text
flow_html = '<html><body><div id="flow-content">Bill text here.</div><div>Chrome.</div></body></html>'
flow_doc = Nokogiri::HTML(flow_html)
AdapterTest.check(
  "extract_full_text targets #flow-content",
  adapter.send(:extract_full_text, flow_doc) == "Bill text here."
)
body_html = '<html><body><p>Body fallback.</p></body></html>'
body_doc = Nokogiri::HTML(body_html)
AdapterTest.check(
  "extract_full_text falls back to body",
  adapter.send(:extract_full_text, body_doc) == "Body fallback."
)

# ──────────────────────────────────────────────────────────────
# 3. Network tests
# ──────────────────────────────────────────────────────────────

if OFFLINE
  AdapterTest.section("Network tests")
  AdapterTest.skip("list_bills", "OFFLINE=1")
  AdapterTest.skip("fetch_bill", "OFFLINE=1")
  AdapterTest.skip("fetch_new_bills (manual check)", "OFFLINE=1")
  AdapterTest.skip("caching verification", "OFFLINE=1")
else
  # ── 3a. list_bills ──────────────────────────────────────────
  AdapterTest.section("list_bills (network)")

  begin
    all_ids = adapter.list_bills(SESSION)
    AdapterTest.check(
      "list_bills('#{SESSION}') returns array of IDs",
      all_ids.is_a?(Array) && all_ids.size.positive?,
      "size=#{all_ids.size}"
    )

    if all_ids.size.positive?
      AdapterTest.check(
        "all IDs are integers",
        all_ids.all? { |id| id.is_a?(Integer) },
        "types=#{all_ids.map(&:class).uniq.inspect}"
      )
      AdapterTest.info("first 5 IDs", all_ids.first(5).inspect)
    end
  rescue => e
    AdapterTest.check("list_bills('#{SESSION}')", false, "#{e.class}: #{e.message}")
    all_ids = []
  end

  # ── 3b. fetch_bill ──────────────────────────────────────────
  AdapterTest.section("fetch_bill (network)")

  fetched_bills = []
  if all_ids.size.positive?
    sample_ids = all_ids.first(LIMIT)

    sample_ids.each_with_index do |source_id, idx|
      AdapterTest.info("Bill #{idx + 1}/#{sample_ids.size}", "source_id=#{source_id}")

      begin
        raw = adapter.fetch_bill(source_id)
        AdapterTest.check("  fetch_bill(#{source_id}) returns RawBill", raw.is_a?(RawBill), "got #{raw.class}")

        next unless raw.is_a?(RawBill)

        fetched_bills << raw

        AdapterTest.field_present?(raw, :jurisdiction,         required: true)
        AdapterTest.field_present?(raw, :legislature_session,  required: true)
        AdapterTest.field_present?(raw, :bill_number,          required: true)
        AdapterTest.field_present?(raw, :bill_type,            required: true)
        AdapterTest.field_present?(raw, :title,                required: true)
        AdapterTest.field_present?(raw, :status,               required: true)
        AdapterTest.field_present?(raw, :source_id,            required: true)
        AdapterTest.field_present?(raw, :source_bill_id,       required: true)
        AdapterTest.field_present?(raw, :parliament_number,    required: true)
        AdapterTest.field_present?(raw, :session_number,       required: true)
        AdapterTest.field_present?(raw, :full_text_url,        required: true)
        AdapterTest.field_present?(raw, :source_url,           required: true)

        AdapterTest.field_present?(raw, :short_title,         required: false)
        AdapterTest.field_present?(raw, :summary,             required: false)
        AdapterTest.field_present?(raw, :sponsor_name,        required: false)
        AdapterTest.field_present?(raw, :introduced_date,     required: false)
        AdapterTest.field_present?(raw, :last_updated_date,    required: false)
        AdapterTest.field_present?(raw, :full_text,            required: false)
        AdapterTest.field_present?(raw, :originating_chamber, required: false)

        valid_types = %w[government private_member senate_public senate_private]
        AdapterTest.check(
          "  bill_type normalized ('#{raw.bill_type}')",
          valid_types.include?(raw.bill_type),
          "should be one of #{valid_types.inspect}"
        )

        AdapterTest.check("  jurisdiction == 'federal'", raw.jurisdiction == "federal")

        AdapterTest.check(
          "  legislature_session format",
          raw.legislature_session.match?(/Parliament.*Session/),
          raw.legislature_session
        )

        # Bill number should look like C-XX or S-XX
        AdapterTest.check(
          "  bill_number format (C- or S- prefix)",
          raw.bill_number.match?(/^[CS]-\d+$/),
          "got '#{raw.bill_number}'"
        )

        # full_text_url should NOT have /html suffix and bill code should be lowercase
        AdapterTest.check(
          "  full_text_url has no /html suffix",
          !raw.full_text_url.end_with?("/html"),
          "url=#{raw.full_text_url}"
        )
        AdapterTest.check(
          "  full_text_url uses lowercase bill code",
          raw.full_text_url.match?(%r{/bill/[cs]-\d+/}),
          "url=#{raw.full_text_url}"
        )

        # source_id and source_bill_id should match
        AdapterTest.check(
          "  source_bill_id matches source_id",
          raw.source_bill_id == source_id,
          "source_bill_id=#{raw.source_bill_id}, source_id=#{source_id}"
        )

        if raw.summary
          AdapterTest.check(
            "  summary has meaningful content (>20 chars)",
            raw.summary.strip.length > 20,
            "length=#{raw.summary.strip.length}"
          )
          preview = raw.summary.strip[0, 120].gsub("\n", " ")
          AdapterTest.info("  summary preview", "#{preview}...")
        else
          AdapterTest.skip("  summary content check", "no summary extracted")
        end

        if raw.full_text
          AdapterTest.check(
            "  full_text has content (>50 chars)",
            raw.full_text.strip.length > 50,
            "length=#{raw.full_text.strip.length}"
          )
        else
          AdapterTest.skip("  full_text content check", "no full text extracted")
        end

        if raw.introduced_date
          AdapterTest.check(
            "  introduced_date is a Date",
            raw.introduced_date.is_a?(Date),
            "got #{raw.introduced_date.class}"
          )
          AdapterTest.info("  introduced_date", raw.introduced_date.iso8601)
        end

        AdapterTest.info("  bill_number", raw.bill_number)
        AdapterTest.info("  bill_type",   raw.bill_type)
        AdapterTest.info("  status",      raw.status)
        AdapterTest.info("  chamber",     raw.originating_chamber || "(nil)")
      rescue => e
        AdapterTest.check("  fetch_bill(#{source_id})", false, "#{e.class}: #{e.message}")
      end
    end
  else
    AdapterTest.skip("fetch_bill", "no bill IDs from list_bills")
  end

  # ── 3c. fetch_new_bills (manual filtered check) ────────────
  # We don't call fetch_new_bills directly because it iterates every
  # matching bill (1.5s sleep each = minutes for ~150 bills).
  # Instead we replicate the same filter on the cached bills_list and
  # verify exactly which bills would be returned, then fully fetch
  # only the first one.
  AdapterTest.section("fetch_new_bills (manual check)")

  begin
    since = Date.today - SINCE_DAYS
    AdapterTest.info("since", since.iso8601)

    all_bills = adapter.send(:bills_list)
    matching = all_bills.select do |b|
      updated = adapter.send(:parse_date, b["LatestActivityDateTime"])
      updated && updated >= since
    end

    AdapterTest.check(
      "found bills updated since #{since}",
      matching.size.positive?,
      "count=#{matching.size}"
    )

    if matching.size.positive?
      AdapterTest.info("matching bills", matching.size)

      first = matching.first
      AdapterTest.info("first matching bill", "BillId=#{first['BillId']} NumberCode=#{first['BillNumberFormatted']}")

      # Verify the date filter is correct
      first_date = adapter.send(:parse_date, first["LatestActivityDateTime"])
      AdapterTest.check(
        "first bill date >= since",
        first_date && first_date >= since,
        "first_date=#{first_date}, since=#{since}"
      )

      # Actually invoke fetch_new_bills with a very narrow window (1 day)
      # to ensure the method end-to-end works without paying for 100+ fetches
      narrow_since = Date.today - 1
      AdapterTest.info("narrow fetch_new_bills since", narrow_since.iso8601)
      narrow_results = adapter.fetch_new_bills(narrow_since)
      AdapterTest.check(
        "fetch_new_bills(narrow) returns array",
        narrow_results.is_a?(Array),
        "class=#{narrow_results.class}"
      )

      if narrow_results.size.positive?
        first_raw = narrow_results.first
        AdapterTest.check("  first result is RawBill", first_raw.is_a?(RawBill))
        AdapterTest.info("  bill_number", first_raw.bill_number)
        AdapterTest.info("  last_updated_date", first_raw.last_updated_date&.iso8601)
      else
        AdapterTest.skip("  first result check", "no bills updated in last 24h")
      end
    end
  rescue => e
    AdapterTest.check("fetch_new_bills manual check", false, "#{e.class}: #{e.message}")
  end

  # ── 3d. Caching verification ────────────────────────────────
  AdapterTest.section("caching (network)")

  begin
    require "benchmark"
    AdapterTest.info("list_bills (first call)", "fetching...")
    t1 = Benchmark.realtime { adapter.list_bills(SESSION) }
    AdapterTest.info("list_bills (second call)", "should use cache...")
    t2 = Benchmark.realtime { adapter.list_bills(SESSION) }

    AdapterTest.check(
      "second list_bills call is faster (cache hit)",
      t2 < t1,
      "1st=%.3fs, 2nd=%.3fs" % [ t1, t2 ]
    )
  rescue => e
    AdapterTest.check("caching verification", false, "#{e.class}: #{e.message}")
  end
end

# ──────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────

AdapterTest.print_summary
