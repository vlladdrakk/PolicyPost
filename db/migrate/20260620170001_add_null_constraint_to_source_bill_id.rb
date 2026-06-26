class AddNullConstraintToSourceBillId < ActiveRecord::Migration[8.1]
  def up
    Bill.where(source_bill_id: nil).delete_all
    change_column_null :bills, :source_bill_id, false
  end

  def down
    change_column_null :bills, :source_bill_id, true
  end
end
