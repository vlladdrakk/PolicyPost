class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.string :category, null: false
      t.string :position, null: false
      t.string :question_type, null: false
      t.integer :priority, default: 0, null: false
      t.text :body, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end
end
