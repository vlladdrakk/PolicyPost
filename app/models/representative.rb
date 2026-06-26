class Representative < ApplicationRecord
  belongs_to :riding, optional: true
  has_many :user_sessions, dependent: :destroy
  has_many :constituent_letters, dependent: :restrict_with_error

  validates :title, :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }

  def display_name
    "#{title} #{name}".strip
  end
end
