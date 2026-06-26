class PostalCode < ApplicationRecord
  belongs_to :riding

  validates :code, presence: true, uniqueness: true,
    format: {
      with: /\A[A-Z]\d[A-Z]\s?\d[A-Z]\d\z/i,
      message: "must be a valid Canadian postal code (e.g. K1A 0A6)"
    }

  before_validation :normalize_code

  private

  def normalize_code
    self.code = code.to_s.upcase.gsub(/\s+/, "").insert(3, " ") if code.present?
  end
end
