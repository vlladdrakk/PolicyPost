class AddStatusToEmailDrafts < ActiveRecord::Migration[8.1]
  def change
    add_column :email_drafts, :status, :string, default: "pending"
    add_column :email_drafts, :last_attempted_at, :datetime
    add_index :email_drafts, :status
  end
end
