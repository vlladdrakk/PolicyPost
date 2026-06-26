puts "Seeding questions..."
count = 0

QUESTION_TYPES = {
  personal_impact: {
    priority: 1,
    support:  "How has {bill_subject} made a positive difference for you or people you know?",
    oppose:   "What negative impact has {bill_subject} had on you or people you know?"
  },
  experience: {
    priority: 2,
    support:  "Can you share a specific example of how {bill_subject} has helped you or your community?",
    oppose:   "Can you share a specific example of how {bill_subject} has caused problems for you or your community?"
  },
  expertise: {
    priority: 3,
    support:  "Do you have professional or lived experience with {bill_subject} that informs your support?",
    oppose:   "Do you have professional or lived experience with {bill_subject} that informs your concerns?"
  },
  values: {
    priority: 4,
    support:  "Which value or principle does {bill_subject} reflect or protect for you?",
    oppose:   "Which value or principle do you feel {bill_subject} undermines?"
  },
  specific_concern: {
    priority: 5,
    support:  "What part of {bill_subject} matters most to you, and why do you support it?",
    oppose:   "What is your biggest concern about {bill_subject}, and why do you oppose it?"
  },
  desired_outcome: {
    priority: 6,
    support:  "What outcome would you most like to see from {bill_subject}?",
    oppose:   "What specific change would need to happen for you to support {bill_subject}?"
  },
  local_impact: {
    priority: 7,
    support:  "How would {bill_subject} benefit your riding or local community?",
    oppose:   "How would {bill_subject} affect your riding or local community?"
  },
  accountability: {
    priority: 8,
    support:  "What would you like your representative to do to advance {bill_subject}?",
    oppose:   "What would you like your representative to do to address your concerns about {bill_subject}?"
  }
}.freeze

DomainConstants::CATEGORIES.each do |category|
  %w[support oppose].each do |position|
    QUESTION_TYPES.each do |type_key, config|
      Question.create!(
        category:      category,
        position:      position,
        question_type: type_key.to_s,
        priority:      config[:priority],
        active:        true,
        source:        "template",
        status:        "approved",
        body:          config[position.to_sym]
      )
      count += 1
    end
  end
end

puts "Created #{count} questions."
