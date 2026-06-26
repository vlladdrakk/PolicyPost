class RawBill
  ATTRIBUTES = %i[
    jurisdiction legislature_session bill_number bill_type title
    short_title summary sponsor_name sponsor_riding sponsor_party status
    introduced_date last_updated_date full_text_url full_text source_url
    source_id source_bill_id parliament_number session_number
    is_government_bill originating_chamber
  ].freeze

  attr_accessor(*ATTRIBUTES)

  def initialize(**attrs)
    ATTRIBUTES.each do |attr|
      instance_variable_set("@#{attr}", attrs.fetch(attr, nil))
    end
  end

  def to_h
    ATTRIBUTES.index_with { |attr| public_send(attr) }
  end
end
