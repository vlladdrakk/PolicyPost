class ConstituentLetter < ApplicationRecord
  include DomainConstants

  RECIPIENT_TYPES = %w[local_mp prime_minister cabinet_minister].freeze

  belongs_to :riding, optional: true
  belongs_to :representative
  belongs_to :bill
  has_many :intake_answers, dependent: :destroy
  has_many :email_drafts, dependent: :destroy

  validates :position, presence: true
  validates :position, inclusion: { in: POSITIONS }
  validates :drafting_approach, inclusion: { in: DRAFTING_APPROACHES }
  validates :recipient_type, inclusion: { in: RECIPIENT_TYPES }
  validates :postal_code, presence: true, if: :local_mp?

  def local_mp?
    recipient_type == "local_mp"
  end

  def prime_minister?
    recipient_type == "prime_minister"
  end

  def cabinet_minister?
    recipient_type == "cabinet_minister"
  end
end
