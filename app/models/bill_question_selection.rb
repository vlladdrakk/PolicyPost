class BillQuestionSelection < ApplicationRecord
  include DomainConstants

  belongs_to :bill
  belongs_to :question
  has_many :question_phrases, dependent: :destroy

  validates :position, presence: true, inclusion: { in: POSITIONS }

  scope :for_position, ->(pos) { where(position: pos) }
end
