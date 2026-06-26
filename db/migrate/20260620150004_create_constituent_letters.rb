class CreateConstituentLetters < ActiveRecord::Migration[8.1]
  def change
    create_table :constituent_letters do |t|
      t.string :postal_code, null: false
      t.references :riding, null: false, foreign_key: true
      t.references :representative, null: false, foreign_key: true
      t.references :bill, null: false, foreign_key: true
      t.string :position, null: false
      t.string :drafting_approach, null: false, default: "B"

      t.timestamps
    end
  end
end
