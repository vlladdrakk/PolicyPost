class IntakeAnswer < ApplicationRecord
  include DomainConstants

  belongs_to :constituent_letter
  belongs_to :question

  validates :answer, presence: true
  validates :verdict, inclusion: { in: VERDICTS }, allow_nil: true
end
