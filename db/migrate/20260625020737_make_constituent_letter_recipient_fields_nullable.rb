class MakeConstituentLetterRecipientFieldsNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :constituent_letters, :postal_code, true
    change_column_null :constituent_letters, :riding_id, true
  end
end
