namespace :representatives do
  desc "Import all federal MPs + ridings from Represent API"
  task import_federal: :environment do
    result = PolicyPost::RepresentativeImporter.import_all!

    puts "Ridings created: #{result.ridings_count}"
    puts "Representatives created: #{result.representatives_count}"
    puts "Errors: #{result.errors.count}"
    result.errors.each { |e| puts "  - #{e}" }
  end

  desc "Seed postal codes from data file"
  task seed_postal_codes: :environment do
    yml_path = Rails.root.join("lib/data/postal_codes.yml")
    unless File.exist?(yml_path)
      puts "Postal codes data file not found at #{yml_path}"
      exit 1
    end

    data = YAML.safe_load_file(yml_path)
    importer = PolicyPost::RepresentativeImporter.new
    count, errors = importer.seed_postal_codes!(data)

    puts "Postal codes created: #{count}"
    puts "Errors: #{errors.count}"
    errors.each { |e| puts "  - #{e}" }
  end

  desc "Import all MPs and seed postal codes"
  task full_setup: :environment do
    Rake::Task["representatives:import_federal"].invoke
    Rake::Task["representatives:seed_postal_codes"].invoke
  end
end
