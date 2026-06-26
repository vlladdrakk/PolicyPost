class CreateIntakeAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :intake_answers do |t|
      t.references :user_session, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.text :answer, null: false
      t.text :follow_up_answer
      t.string :verdict

      t.timestamps
    end
  end
end
