class AddFollowUpTextToIntakeAnswers < ActiveRecord::Migration[8.1]
  def change
    add_column :intake_answers, :follow_up_text, :string
  end
end
