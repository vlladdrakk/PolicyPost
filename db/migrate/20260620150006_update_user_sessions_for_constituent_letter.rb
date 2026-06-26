class UpdateUserSessionsForConstituentLetter < ActiveRecord::Migration[8.1]
  def change
    add_reference :user_sessions, :constituent_letter, null: true, foreign_key: true
    remove_reference :user_sessions, :bill, foreign_key: true
    remove_reference :user_sessions, :representative, foreign_key: true
    remove_column :user_sessions, :position, :string
    remove_column :user_sessions, :drafting_approach, :string
  end
end
