namespace :legisinfo do
  desc "Ingest bills from LEGISinfo for a given session (e.g., rake legisinfo:ingest[45-1])"
  task :ingest, [ :session ] => :environment do |_t, args|
    session = args[:session] || "45-1"
    adapter = FederalAdapter.new

    puts "Fetching bill list for session #{session}..."
    source_ids = adapter.list_bills(session)
    puts "Found #{source_ids.length} bills."

    created = 0
    skipped = 0
    errors = 0

    source_ids.each_with_index do |source_id, i|
      print "[#{i + 1}/#{source_ids.length}] Bill #{source_id}... "

      if Bill.exists?(source_bill_id: source_id)
        puts "already exists, skipping."
        skipped += 1
        next
      end

      raw_bill = adapter.fetch_bill(source_id)
      unless raw_bill
        puts "failed to fetch."
        errors += 1
        next
      end

      bill = Bill.create_from_raw(raw_bill)
      BillProcessingJob.perform_later(bill.id)
      puts "created #{bill.bill_number} (#{bill.status})."
      created += 1
    rescue StandardError => e
      puts "error: #{e.message}"
      errors += 1
    end

    puts "\nDone. Created: #{created}, Skipped: #{skipped}, Errors: #{errors}"
  end
end
