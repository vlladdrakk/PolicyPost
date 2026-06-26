class AddEmailToRepresentatives < ActiveRecord::Migration[8.1]
  def change
    add_column :representatives, :email, :string
  end
end
