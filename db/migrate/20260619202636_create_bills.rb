class CreateBills < ActiveRecord::Migration[8.1]
  def change
    create_table :bills do |t|
      t.string :jurisdiction, null: false
      t.string :legislature_session, null: false
      t.string :bill_number, null: false
      t.string :bill_type
      t.text :title, null: false
      t.string :short_title
      t.text :summary, null: false
      t.string :sponsor_name
      t.string :sponsor_riding
      t.string :sponsor_party
      t.string :status, null: false
      t.date :introduced_date
      t.date :last_updated_date
      t.string :full_text_url, null: false
      t.text :full_text
      t.string :source_url, null: false
      t.string :source_id, null: false
      t.string :category, null: false, default: "governance"
      t.string :processing_status, null: false, default: "pending"

      t.timestamps
    end
    add_index :bills, [ :jurisdiction, :source_id ], unique: true
    add_index :bills, :bill_number
  end
end
