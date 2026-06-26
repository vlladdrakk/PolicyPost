class BillPhrase < ApplicationRecord
  belongs_to :bill
  has_many :question_phrases, dependent: :destroy

  validates :phrase, presence: true

  scope :verified, -> { where(verified: true) }
end
