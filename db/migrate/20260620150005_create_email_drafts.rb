class CreateEmailDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :email_drafts do |t|
      t.references :constituent_letter, null: false, foreign_key: true
      t.text :body, null: false
      t.string :approach, null: false
      t.string :quality_status
      t.text :quality_warnings

      t.timestamps
    end
  end
end
