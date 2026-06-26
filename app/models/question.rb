class Question < ApplicationRecord
  include DomainConstants

  belongs_to :bill, optional: true

  has_many :bill_question_selections, dependent: :destroy
  has_many :bills, through: :bill_question_selections
  has_many :intake_answers, dependent: :destroy

  validates :category, :position, :question_type, :body, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :position, inclusion: { in: POSITIONS }
  validates :source, inclusion: { in: %w[template generated] }
  validates :status, inclusion: { in: %w[pending approved rejected] }
  validate :bill_required_for_generated

  scope :active, -> { where(active: true) }
  scope :templates, -> { where(source: "template") }
  scope :generated, -> { where(source: "generated") }
  scope :approved, -> { where(status: "approved") }
  scope :pending, -> { where(status: "pending") }
  scope :rejected, -> { where(status: "rejected") }
  scope :for_category_and_position, ->(cat, pos) { where(category: cat, position: pos) }
  scope :for_bill, ->(bill) { where(bill: bill) }

  def requires_bill_subject?
    body.include?("{bill_subject}")
  end

  def generated?
    source == "generated"
  end

  private

  def bill_required_for_generated
    if generated? && bill_id.blank?
      errors.add(:bill_id, "is required for generated questions")
    end
  end
end
