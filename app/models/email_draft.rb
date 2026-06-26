class EmailDraft < ApplicationRecord
  include DomainConstants

  QUALITY_STATUSES = %w[pass pass_with_warning show_with_warnings].freeze

  belongs_to :constituent_letter

  validates :body, :approach, presence: true
  validates :approach, inclusion: { in: DRAFTING_APPROACHES }
  validates :quality_status, inclusion: { in: QUALITY_STATUSES }, allow_nil: true
  validates :status, inclusion: { in: DRAFT_STATUSES, message: "%{value} is not a valid draft status" }, allow_nil: true

  scope :processing, -> { where(status: "processing") }
  scope :complete,   -> { where(status: "complete") }
  scope :failed,     -> { where(status: "failed") }

  after_initialize :set_default_status, if: :new_record?

  def processing!
    save!(validate: false) if new_record?
    update_columns(status: "processing", last_attempted_at: Time.current)
  end

  def complete!
    update!(status: "complete")
  end

  def failed!
    update!(status: "failed")
  end

  private

  def set_default_status
    self.status ||= "pending"
  end
end
