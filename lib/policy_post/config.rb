module PolicyPost::Config
  POSITION_CONFIG = {
    "support" => {
      position_description: "The constituent supports this bill.",
      position_verb: "support",
      action_based_on_position: "vote for"
    },
    "oppose" => {
      position_description: "The constituent opposes this bill.",
      position_verb: "oppose",
      action_based_on_position: "vote against"
    },
    "support_with_amendments" => {
      position_description: "The constituent supports this bill with amendments.",
      position_verb: "support with amendments to",
      action_based_on_position: "propose amendments to"
    }
  }.freeze

  DRAFTING_CONFIG = {
    default_approach: "B",
    ab_test: {
      enabled: true,
      traffic_split: { "A" => 0.5, "B" => 0.5 },
      tracking_key: "drafting_approach"
    },
    fallback: {
      a_failure_retry_with: "B",
      b_failure_retry_with: nil
    }
  }.freeze

  QUESTION_GENERATION_CONFIG = {
    target_count: 3,
    max_count: 3
  }.freeze

  QUESTION_SELECTION_CONFIG = {
    target_count: 3,
    min_count: 2,
    max_count: 3
  }.freeze
end
