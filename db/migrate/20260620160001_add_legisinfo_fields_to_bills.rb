class AddLegisinfoFieldsToBills < ActiveRecord::Migration[8.1]
  def change
    add_column :bills, :source_bill_id, :integer
    add_column :bills, :parliament_number, :integer
    add_column :bills, :session_number, :integer
    add_column :bills, :is_government_bill, :boolean, default: false, null: false
    add_column :bills, :originating_chamber, :string

    add_index :bills, :source_bill_id, unique: true

    change_column_null :bills, :summary, true
    change_column_null :bills, :full_text_url, true
  end
end
