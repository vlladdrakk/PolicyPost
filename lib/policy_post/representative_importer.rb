require "net/http"
require "json"

module PolicyPost
  class RepresentativeImporter
    REPRESENT_API = "https://represent.opennorth.ca"
    FED_BOUNDARIES = "/boundaries/federal-electoral-districts-2023-representation-order/"
    HOUSE_OF_COMMONS = "/representatives/house-of-commons/"
    PAGE_LIMIT = 100

    # Elections Canada FED numbering — first two digits encode province.
    FED_PROVINCE_MAP = {
      (10_000..10_999) => "NL",
      (11_000..11_999) => "PE",
      (12_000..12_999) => "NS",
      (13_000..13_999) => "NB",
      (24_000..24_999) => "QC",
      (35_000..35_999) => "ON",
      (46_000..46_999) => "MB",
      (47_000..47_999) => "SK",
      (48_000..48_999) => "AB",
      (59_000..59_999) => "BC",
      (60_000..60_999) => "YT",
      (61_000..61_999) => "NT",
      (62_000..62_999) => "NU"
    }.freeze

    IMPORT_RESULT = Struct.new(:ridings_count, :representatives_count, :postal_codes_count, :errors, keyword_init: true)

    def self.import_all!
      new.import_all!
    end

    def initialize(http: nil)
      @http = http || Net::HTTP
    end

    def import_all!
      errors = []

      boundaries = fetch_all(fetch_json("#{REPRESENT_API}#{FED_BOUNDARIES}?limit=#{PAGE_LIMIT}"), FED_BOUNDARIES)
      ridings_index = build_ridings_index(boundaries)

      mps = fetch_all(fetch_json("#{REPRESENT_API}#{HOUSE_OF_COMMONS}?limit=#{PAGE_LIMIT}"), HOUSE_OF_COMMONS)

      ridings_created = 0
      reps_created = 0

      mps.each do |mp|
        district_name = mp["district_name"]
        boundary = ridings_index[normalize_riding_name(district_name)]
        unless boundary
          errors << "No boundary found for #{district_name}"
          next
        end

        fed_num = extract_fed_num(boundary)
        province = self.class.province_from_fed_num(fed_num)
        unless province
          errors << "Unknown province for FED #{fed_num} (#{district_name})"
          next
        end

        riding = Riding.find_or_create_by!(name: boundary["name"], province: province) do |r|
          r.federal_riding_code = fed_num.to_s
        end

        riding.update!(federal_riding_code: fed_num.to_s) if riding.federal_riding_code.blank?

        ridings_created += 1 if riding.previous_changes.key?("id")

        title = mp["elected_office"] == "MP" ? "MP" : "Hon."

        role = extract_minister_role(mp)
        is_minister = role.present?
        ministry_name = role

        email = mp["email"].to_s.strip.presence

        rep = Representative.find_or_create_by!(riding: riding, name: mp["name"]) do |r|
          r.title = title
          r.is_minister = is_minister
          r.ministry_name = ministry_name
          r.email = email
        end

        rep.update!(title: title, is_minister: is_minister, ministry_name: ministry_name) if rep.is_minister != is_minister || rep.title != title
        rep.update!(email: email) if rep.email.blank? && email.present?

        reps_created += 1 if rep.previous_changes.key?("id")
      rescue StandardError => e
        errors << "#{mp["name"]}: #{e.message}"
      end

      IMPORT_RESULT.new(
        ridings_count: ridings_created,
        representatives_count: reps_created,
        postal_codes_count: 0,
        errors: errors
      )
    end

    def seed_postal_codes!(postal_codes_data)
      errors = []
      count = 0

      postal_codes_data.each do |entry|
        riding = Riding.find_by(name: entry["riding"], province: entry["province"])
        unless riding
          errors << "No riding found for #{entry["code"]} (#{entry["riding"]}, #{entry["province"]})"
          next
        end

        PostalCode.find_or_create_by!(code: entry["code"]) do |pc|
          pc.riding = riding
        end
        count += 1
      rescue StandardError => e
        errors << "#{entry["code"]}: #{e.message}"
      end

      [ count, errors ]
    end

    # Look up a postal code via the Represent API and cache locally.
    # Creates the Riding, Representative (federal MP), and PostalCode records.
    def self.lookup_postal_code(code)
      normalized = code.to_s.upcase.gsub(/\s+/, "").insert(3, " ")
      cached = PostalCode.find_by(code: normalized)
      return cached if cached

      json = fetch_json_safely("#{REPRESENT_API}/postcodes/#{code.strip}/")
      return nil unless json

      boundaries = json["boundaries_centroid"] || []
      fed_boundary = boundaries.find { |b| b["boundary_set_name"] == "Federal electoral district" }
      return nil unless fed_boundary

      riding_name = fed_boundary["name"]
      fed_num = fed_boundary["external_id"].to_i
      province = province_from_fed_num(fed_num)
      return nil unless province

      riding = Riding.find_or_create_by!(name: riding_name, province: province) do |r|
        r.federal_riding_code = fed_num.to_s
      end

      # Look up the federal MP from the same API response.
      reps = json["representatives_centroid"] || []
      fed_mp = reps.find { |r| r["elected_office"] == "MP" && r["representative_set_name"] == "House of Commons" }

      if fed_mp
        mp_role = extract_minister_role_static(fed_mp)
        email = fed_mp["email"].to_s.strip.presence
        Representative.find_or_create_by!(riding: riding, name: fed_mp["name"]) do |rep|
          rep.title = "MP"
          rep.is_minister = mp_role.present?
          rep.ministry_name = mp_role
          rep.email = email
        end
      end

      PostalCode.create!(code: normalized, riding: riding)
    rescue StandardError => e
      Rails.logger.warn "[RepresentativeImporter] Failed to look up #{code}: #{e.message}"
      nil
    end

    def self.province_from_fed_num(fed_num)
      FED_PROVINCE_MAP.each { |range, abbr| return abbr if range.include?(fed_num) }
      nil
    end

    def self.extract_minister_role_static(mp)
      extra = mp["extra"] || {}
      roles = extra["roles"] || []
      minister_role = roles.find { |r| r.match?(/\bMinister\b/i) }
      return nil unless minister_role

      match = minister_role.match(/Minister of ([^(]+)/)
      match ? match[1].strip : minister_role
    end

    private

    def fetch_all(initial_response, endpoint = nil)
      objects = initial_response["objects"] || []
      meta = initial_response["meta"] || {}
      total = meta["total_count"] || objects.length
      offset = meta["offset"] || 0

      # Determine the endpoint for subsequent pages.
      base_endpoint = endpoint || guess_endpoint(initial_response)

      while offset + PAGE_LIMIT < total
        offset += PAGE_LIMIT
        url = "#{REPRESENT_API}#{base_endpoint}?limit=#{PAGE_LIMIT}&offset=#{offset}"
        response = fetch_json(url)
        objects.concat(response["objects"] || [])
      end

      objects
    end

    def guess_endpoint(response)
      response.dig("objects", 0, "elected_office") ? HOUSE_OF_COMMONS : FED_BOUNDARIES
    end

    def build_ridings_index(boundaries)
      boundaries.each_with_object({}) do |b, idx|
        idx[normalize_riding_name(b["name"])] = b
      end
    end

    def normalize_riding_name(name)
      name.to_s
        .gsub("\u2014", "-")   # em-dash to hyphen
        .gsub("\u2013", "-")   # en-dash to hyphen
        .gsub(/['']/, "'")     # curly quotes to straight
        .gsub(/\s+/, " ")      # collapse whitespace
        .gsub(/[–—]/, "-")    # extra dash variants
        .strip
        .downcase
    end

    def extract_fed_num(boundary)
      meta = boundary["metadata"] || {}
      meta["FED_NUM"]&.to_i || meta["FEDUID"]&.to_i || boundary["external_id"]&.to_i || 0
    end

    def extract_minister_role(mp)
      extra = mp["extra"] || {}
      roles = extra["roles"] || []
      minister_role = roles.find { |r| r.match?(/\bMinister\b/i) }
      return nil unless minister_role

      match = minister_role.match(/Minister of ([^(]+)/)
      match ? match[1].strip : minister_role
    end

    def fetch_json(url)
      response = http_get(url)
      raise "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    end

    def self.fetch_json_safely(url)
      response = http_get_static(url)
      return nil unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    rescue StandardError
      nil
    end

    def http_get(url, limit = 5)
      uri = URI(url)
      response = @http.get_response(uri)

      if response.is_a?(Net::HTTPRedirection) && limit > 0
        redirect_uri = URI(response["location"])
        # Handle relative redirects.
        redirect_uri = URI.join(url, response["location"]) unless redirect_uri.host
        http_get(redirect_uri.to_s, limit - 1)
      else
        response
      end
    end

    def self.http_get_static(url, limit = 5)
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPRedirection) && limit > 0
        redirect_uri = URI(response["location"])
        redirect_uri = URI.join(url, response["location"]) unless redirect_uri.host
        http_get_static(redirect_uri.to_s, limit - 1)
      else
        response
      end
    end
  end
end
