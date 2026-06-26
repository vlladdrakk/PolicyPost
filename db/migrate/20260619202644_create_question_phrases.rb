class CreateQuestionPhrases < ActiveRecord::Migration[8.1]
  def change
    create_table :question_phrases do |t|
      t.references :bill_question_selection, null: false, foreign_key: true
      t.references :bill_phrase, null: false, foreign_key: true
      t.integer :rank, null: false, default: 1

      t.timestamps
    end
    add_index :question_phrases, [ :bill_question_selection_id, :rank ]
  end
end
