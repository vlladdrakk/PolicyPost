class CreatePostalCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :postal_codes do |t|
      t.string :code, null: false
      t.references :riding, null: false, foreign_key: true

      t.timestamps
    end

    add_index :postal_codes, :code, unique: true
  end
end
