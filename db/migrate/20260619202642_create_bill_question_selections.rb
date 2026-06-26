class CreateBillQuestionSelections < ActiveRecord::Migration[8.1]
  def change
    create_table :bill_question_selections do |t|
      t.references :bill, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.string :position, null: false

      t.timestamps
    end
    add_index :bill_question_selections, [ :bill_id, :position, :question_id ], unique: true
  end
end
