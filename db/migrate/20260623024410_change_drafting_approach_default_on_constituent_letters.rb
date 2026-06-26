class ChangeDraftingApproachDefaultOnConstituentLetters < ActiveRecord::Migration[8.1]
  def change
    change_column_default :constituent_letters, :drafting_approach, from: "B", to: "A"
  end
end
