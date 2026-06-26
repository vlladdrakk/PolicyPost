require "net/http"
require "json"

class FederalAdapter < BillAdapter
  BASE_URL = "https://www.parl.ca/LegisInfo"
  DOC_VIEWER_BASE = "https://www.parl.ca/DocumentViewer"
  RATE_LIMIT_DELAY = 1.5

  BILLS_JSON_URL = "#{BASE_URL}/en/bills/json"

  # Match the actual values seen in LEGISinfo's CurrentStatusEn field.
  STATUS_EXACT_MAP = {
    "royal assent"   => "royal_assent",
    "defeated"       => "defeated"
  }.freeze

  # Substring matching is case-insensitive against CurrentStatusEn.
  # Order matters: longer phrases MUST come before shorter overlapping
  # ones (e.g. "at second reading" before "second reading"). Default
  # fallback returns "introduced".
  STATUS_MAP = [
    [ "introduction and first reading", "introduced" ],
    [ "introduced and first reading",   "introduced" ],
    [ "introduced as pro forma bill",   "introduced" ],
    [ "awaiting first reading",         "introduced" ],
    [ "outside the order of precedence", "introduced" ],
    [ "at second reading",              "second_reading" ],
    [ "second reading",                 "second_reading" ],
    [ "at consideration in committee",   "committee" ],
    [ "consideration in committee",     "committee" ],
    [ "at report stage",                "committee" ],
    [ "report stage",                   "committee" ],
    [ "at third reading",               "third_reading" ],
    [ "third reading",                  "third_reading" ],
    [ "royal assent",                   "royal_assent" ],
    [ "defeated",                       "defeated" ]
  ].freeze

  # BillTypeEn substring matching (case-insensitive). The data uses both
  # straight and curly apostrophes in "Private Member's Bill", so substring
  # matching on "private member" is safer than exact keys.
  BILL_TYPE_SUBSTR = [
    [ "government bill",  "government" ],
    [ "private member",   "private_member" ],
    [ "senate public",    "senate_public" ],
    [ "senate private",   "senate_private" ]
  ].freeze

  # OriginatingChamberId values used by LEGISinfo.
  HOUSE_OF_COMMONS_ID = 1
  SENATE_ID = 2

  def list_bills(session = nil)
    bills = bills_list

    if session
      parliament, sess = parse_session(session)
      bills = bills.select do |b|
        b["ParliamentNumber"] == parliament && b["SessionNumber"] == sess
      end
    end

    bills.filter_map { |b| b["BillId"] }
  end

  def fetch_bill(source_id, json: nil)
    json ||= fetch_bill_json(source_id)
    return nil unless json

    parliament = json["ParliamentNumber"]
    session = json["SessionNumber"]
    bill_code = json["BillNumberFormatted"]
    stage = slugify_stage(json["LatestCompletedMajorStageEn"])

    bill_url = "#{DOC_VIEWER_BASE}/en/#{parliament}-#{session}/bill/#{bill_code.downcase}/#{stage}"
    summary, full_text = fetch_bill_text(bill_url)

    bill_type = normalize_bill_type(json["BillTypeEn"])
    chamber_id = json["OriginatingChamberId"]
    originating_chamber = chamber_name(chamber_id)

    introduced = if chamber_id == SENATE_ID
      parse_date(json["PassedSenateFirstReadingDateTime"])
    else
      parse_date(json["PassedHouseFirstReadingDateTime"])
    end

    RawBill.new(
      jurisdiction: "federal",
      legislature_session: "#{ordinal(parliament)} Parliament, #{ordinal(session)} Session",
      bill_number: bill_code,
      bill_type: bill_type,
      title: json["LongTitleEn"],
      short_title: json["ShortTitleEn"].presence,
      summary: summary,
      sponsor_name: json["SponsorEn"].presence,
      sponsor_riding: nil,
      sponsor_party: nil,
      status: normalize_status(json["CurrentStatusEn"]),
      introduced_date: introduced,
      last_updated_date: parse_date(json["LatestActivityDateTime"]),
      full_text_url: bill_url,
      full_text: full_text,
      source_url: "#{BASE_URL}/en/bill/#{parliament}-#{session}/#{bill_code.downcase}",
      source_id: json["BillId"].to_s,
      source_bill_id: json["BillId"],
      parliament_number: parliament,
      session_number: session,
      is_government_bill: /government/i.match?(json["BillTypeEn"].to_s),
      originating_chamber: originating_chamber
    )
  end

  def fetch_new_bills(since = nil)
    bills = bills_list

    if since
      bills = bills.select do |b|
        updated = parse_date(b["LatestActivityDateTime"])
        updated && updated >= since
      end
    end

    bills.filter_map { |b| fetch_bill(b["BillId"], json: b) }
  end

  def normalize_status(raw_status)
    return "introduced" if raw_status.blank?

    downcased = raw_status.downcase.strip

    # Exact wins before substring match (e.g. "Royal Assent" is canonical
    # exactly; "Royal assent received" also matches via STATUS_MAP).
    return STATUS_EXACT_MAP[downcased] if STATUS_EXACT_MAP.key?(downcased)

    STATUS_MAP.each do |substr, value|
      return value if downcased.include?(substr)
    end

    "introduced"
  end

  private

  def fetch_json(url)
    uri = URI(url)
    response = Net::HTTP.get_response(uri)
    sleep(RATE_LIMIT_DELAY)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("FederalAdapter: HTTP #{response.code} for #{url}")
      return []
    end

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("FederalAdapter: Failed to fetch #{url}: #{e.message}")
    []
  end

  def bills_list
    @bills_list ||= begin
      json = fetch_json(BILLS_JSON_URL)
      json.is_a?(Array) ? json : [ json ]
    end
  end

  def fetch_bill_json(source_id)
    cached = bills_list.find { |b| b["BillId"] == source_id }
    return cached if cached

    single_bill_url = "#{BASE_URL}/en/bill/json/#{source_id}"
    json = fetch_json(single_bill_url)
    bills = json.is_a?(Array) ? json : [ json ]
    bills.find { |b| b["BillId"] == source_id }
  end

  def fetch_bill_text(url)
    uri = URI(url)
    response = Net::HTTP.get_response(uri)
    sleep(RATE_LIMIT_DELAY)

    return [ nil, nil ] unless response.is_a?(Net::HTTPSuccess)

    doc = Nokogiri::HTML(response.body)
    summary = extract_summary(doc)
    full_text = extract_full_text(doc)
    [ summary, full_text ]
  rescue StandardError => e
    Rails.logger.error("FederalAdapter: Failed to fetch bill text from #{url}: #{e.message}")
    [ nil, nil ]
  end

  def extract_summary(doc)
    summary_heading = doc.at_xpath("//h2[contains(text(), 'SUMMARY')]")
    return nil unless summary_heading

    paragraphs = []
    sibling = summary_heading.next_element
    while sibling && sibling.name != "h2"
      text = sibling.text.strip
      paragraphs << text if text.present?
      sibling = sibling.next_element
    end

    paragraphs.join("\n\n").presence
  end

  def extract_full_text(doc)
    content = doc.at_css("#flow-content") || doc.at_css("body")
    return nil unless content

    text = content.text
    text = text.gsub(/[ \t]+/, " ")
    text = text.gsub(/\n{3,}/, "\n\n")
    text.strip.presence
  end

  def slugify_stage(stage_name)
    return "first-reading" if stage_name.blank?

    stage_name.downcase.gsub(/\s+/, "-").gsub(/[^a-z-]/, "")
  end

  def normalize_bill_type(bill_type_en)
    return nil if bill_type_en.blank?

    downcased = bill_type_en.downcase
    BILL_TYPE_SUBSTR.each do |substr, value|
      return value if downcased.include?(substr)
    end

    downcased.gsub(/\s+/, "_")
  end

  def chamber_name(chamber_id)
    case chamber_id
    when HOUSE_OF_COMMONS_ID then "House of Commons"
    when SENATE_ID then "Senate"
    end
  end

  def parse_session(session_string)
    parts = session_string.split("-")
    [ parts[0].to_i, parts[1].to_i ]
  end

  def ordinal(n)
    return "#{n}th" if (11..13).include?(n % 100)

    case n % 10
    when 1 then "#{n}st"
    when 2 then "#{n}nd"
    when 3 then "#{n}rd"
    else "#{n}th"
    end
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    Date.parse(date_string)
  rescue ArgumentError
    nil
  end
end
