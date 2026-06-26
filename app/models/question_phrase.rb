class QuestionPhrase < ApplicationRecord
  belongs_to :bill_question_selection
  belongs_to :bill_phrase

  validates :rank, presence: true, inclusion: { in: 1..3 }

  scope :ranked, -> { order(:rank) }
end
