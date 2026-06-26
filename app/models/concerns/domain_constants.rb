module DomainConstants
  CATEGORIES = %w[
    healthcare education environment housing labour tax justice
    transportation indigenous digital social_services governance
  ].freeze

  POSITIONS = %w[support oppose support_with_amendments].freeze

  STATUSES = %w[
    introduced first_reading second_reading committee
    third_reading royal_assent defeated
  ].freeze

  PROCESSING_STATUSES = %w[pending processing review approved rejected].freeze

  DRAFTING_APPROACHES = %w[A B].freeze

  VERDICTS = %w[good vague].freeze

  DRAFT_STATUSES = %w[pending processing complete failed].freeze
end
