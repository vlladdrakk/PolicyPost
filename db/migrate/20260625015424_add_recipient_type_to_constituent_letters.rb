class AddRecipientTypeToConstituentLetters < ActiveRecord::Migration[8.1]
  def change
    add_column :constituent_letters, :recipient_type, :string, default: "local_mp", null: false
  end
end
