class AddSourceAndBillToQuestions < ActiveRecord::Migration[8.1]
  def up
    add_column :questions, :source, :string, null: false, default: "template"
    add_reference :questions, :bill, null: true, foreign_key: true
    add_column :questions, :status, :string, null: false, default: "approved"

    add_index :questions, [ :bill_id, :position, :status ]
    add_index :questions, [ :source, :status ]
  end

  def down
    remove_index :questions, [ :source, :status ]
    remove_index :questions, [ :bill_id, :position, :status ]
    remove_column :questions, :status
    remove_reference :questions, :bill
    remove_column :questions, :source
  end
end
