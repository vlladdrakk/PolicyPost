class UserSession < ApplicationRecord
  belongs_to :constituent_letter, optional: true

  validates :postal_code, presence: true, if: :needs_postal_code?
  validates :riding, presence: true, if: :needs_postal_code?

  private

  def needs_postal_code?
    constituent_letter.nil? || constituent_letter.local_mp?
  end
end
