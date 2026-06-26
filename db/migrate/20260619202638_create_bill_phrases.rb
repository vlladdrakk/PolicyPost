class CreateBillPhrases < ActiveRecord::Migration[8.1]
  def change
    create_table :bill_phrases do |t|
      t.references :bill, null: false, foreign_key: true
      t.string :phrase, null: false
      t.boolean :verified, default: true, null: false

      t.timestamps
    end
  end
end
