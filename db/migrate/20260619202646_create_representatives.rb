class CreateRepresentatives < ActiveRecord::Migration[8.1]
  def change
    create_table :representatives do |t|
      t.string :title
      t.string :name
      t.string :riding
      t.boolean :is_minister, default: false, null: false
      t.string :ministry_name

      t.timestamps
    end
  end
end
