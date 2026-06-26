class Riding < ApplicationRecord
  has_many :postal_codes, dependent: :destroy
  has_many :representatives, dependent: :destroy
  has_many :constituent_letters, dependent: :restrict_with_error

  validates :name, :province, presence: true
  validates :name, uniqueness: { scope: :province }
end
