class SeedPrimeMinisterRepresentative < ActiveRecord::Migration[8.1]
  def up
    Representative.find_or_create_by!(title: "Prime Minister", name: "Justin Trudeau") do |rep|
      rep.email = "pm@pm.gc.ca"
    end
  end

  def down
    Representative.where(title: "Prime Minister", name: "Justin Trudeau").destroy_all
  end
end
