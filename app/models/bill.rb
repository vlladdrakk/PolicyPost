class Bill < ApplicationRecord
  include DomainConstants

  has_many :bill_phrases, dependent: :destroy
  has_many :bill_question_selections, dependent: :destroy
  has_many :questions, through: :bill_question_selections
  has_many :generated_questions, class_name: "Question", dependent: :destroy
  has_many :constituent_letters, dependent: :restrict_with_error

  validates :jurisdiction, :legislature_session, :bill_number, :title,
            :status, :source_url, :source_id,
            presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :status, inclusion: { in: STATUSES }
  validates :processing_status, inclusion: { in: PROCESSING_STATUSES }
  validates :source_id, uniqueness: { scope: :jurisdiction }
  validates :source_bill_id, presence: true, uniqueness: true

  scope :approved, -> { where(processing_status: "approved") }
  scope :for_jurisdiction, ->(j) { where(jurisdiction: j) }

  def senate_bill?
    originating_chamber == "Senate"
  end

  def approve!
    unless processing_status == "review"
      errors.add(:processing_status, "must be review to approve, currently #{processing_status}")
      raise ActiveRecord::RecordInvalid.new(self)
    end
    update!(processing_status: "approved")
  end

  def reject!(reason:)
    unless processing_status == "review"
      errors.add(:processing_status, "must be review to reject, currently #{processing_status}")
      raise ActiveRecord::RecordInvalid.new(self)
    end
    if reason.blank?
      raise ArgumentError, "Rejection reason is required"
    end
    update!(processing_status: "rejected", review_notes: reason)
  end

  def self.create_from_raw(raw_bill)
    create!(
      jurisdiction: raw_bill.jurisdiction,
      legislature_session: raw_bill.legislature_session,
      bill_number: raw_bill.bill_number,
      bill_type: raw_bill.bill_type,
      title: raw_bill.title,
      short_title: raw_bill.short_title,
      summary: raw_bill.summary,
      sponsor_name: raw_bill.sponsor_name,
      sponsor_riding: raw_bill.sponsor_riding,
      sponsor_party: raw_bill.sponsor_party,
      status: raw_bill.status,
      introduced_date: raw_bill.introduced_date,
      last_updated_date: raw_bill.last_updated_date,
      full_text_url: raw_bill.full_text_url,
      full_text: raw_bill.full_text,
      source_url: raw_bill.source_url,
      source_id: raw_bill.source_id,
      source_bill_id: raw_bill.source_bill_id,
      parliament_number: raw_bill.parliament_number,
      session_number: raw_bill.session_number,
      is_government_bill: raw_bill.is_government_bill,
      originating_chamber: raw_bill.originating_chamber
    )
  end
end
