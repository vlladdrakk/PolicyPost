class AddReviewNotesToBills < ActiveRecord::Migration[8.1]
  def change
    add_column :bills, :review_notes, :text
  end
end
