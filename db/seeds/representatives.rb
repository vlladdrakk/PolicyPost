puts "Seeding representatives..."

importer = PolicyPost::RepresentativeImporter.new

begin
  result = importer.import_all!
  puts "  Ridings created: #{result.ridings_count}"
  puts "  Representatives created: #{result.representatives_count}"
  if result.errors.any?
    puts "  Errors (#{result.errors.count}):"
    result.errors.first(10).each { |e| puts "    - #{e}" }
  end
rescue StandardError => e
  puts "  Failed to import from Represent API: #{e.message}"
  puts "  Falling back to minimal seed data..."

  riding = Riding.find_or_create_by!(name: "Ottawa Centre", province: "ON") do |r|
    r.federal_riding_code = "35079"
  end

  Representative.find_or_create_by!(riding: riding, name: "Yasir Naqvi") do |rep|
    rep.title = "MP"
    rep.is_minister = false
    rep.email = "Yasir.Naqvi@parl.gc.ca"
  end

  PostalCode.find_or_create_by!(code: "K1P 1A4") do |pc|
    pc.riding = riding
  end
end

# Seed postal codes from data file.
yml_path = Rails.root.join("lib/data/postal_codes.yml")
if File.exist?(yml_path)
  postal_data = YAML.safe_load_file(yml_path)
  count, errors = importer.seed_postal_codes!(postal_data)
  puts "  Postal codes seeded: #{count}"
  if errors.any?
    puts "  Postal code errors (#{errors.count}):"
    errors.first(5).each { |e| puts "    - #{e}" }
  end
else
  puts "  Postal codes data file not found at #{yml_path}, skipping."
end

Representative.find_or_create_by!(title: "Prime Minister", name: "Justin Trudeau") do |rep|
  rep.email = "pm@pm.gc.ca"
end

puts "Done seeding representatives."
