class BillAdapter
  def list_bills(session = nil) = raise(NotImplementedError)
  def fetch_bill(source_id) = raise(NotImplementedError)
  def fetch_new_bills(since = nil) = raise(NotImplementedError)
  def normalize_status(raw_status) = raise(NotImplementedError)
end
