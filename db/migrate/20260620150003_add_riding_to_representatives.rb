class AddRidingToRepresentatives < ActiveRecord::Migration[8.1]
  def change
    add_reference :representatives, :riding, null: true, foreign_key: true
    remove_column :representatives, :riding, :string
  end
end
