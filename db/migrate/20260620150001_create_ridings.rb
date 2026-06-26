class CreateRidings < ActiveRecord::Migration[8.1]
  def change
    create_table :ridings do |t|
      t.string :name, null: false
      t.string :province, null: false
      t.string :federal_riding_code

      t.timestamps
    end

    add_index :ridings, :province
    add_index :ridings, %i[province name], unique: true
  end
end
