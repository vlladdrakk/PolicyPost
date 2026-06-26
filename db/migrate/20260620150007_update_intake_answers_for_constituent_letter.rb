class UpdateIntakeAnswersForConstituentLetter < ActiveRecord::Migration[8.1]
  def change
    add_reference :intake_answers, :constituent_letter, null: false, foreign_key: true
    remove_reference :intake_answers, :user_session, foreign_key: true
  end
end
