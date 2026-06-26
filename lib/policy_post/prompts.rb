module PolicyPost::Prompts
  module_function

  def classification(bill_number:, title:, summary:)
    <<~PROMPT
      Classify this bill into exactly one category.

      Bill: #{bill_number} — #{title}
      Summary: #{summary}

      Categories:
      - healthcare
      - education
      - environment
      - housing
      - labour
      - tax
      - justice
      - transportation
      - indigenous
      - digital
      - social_services
      - governance

      Pick the best fit even if the bill touches multiple topics.
      Choose the category that best matches the bill's primary focus.

      Respond with only the category name. No other text.

      Category:
    PROMPT
  end

  def phrase_extraction(bill_number:, title:, summary:, questions_needing_phrases:, extra_instruction: nil)
    questions_text = questions_needing_phrases.map { |q| "- #{q}" }.join("\n")
    base = <<~PROMPT
      Extract phrases from this bill that could replace {bill_subject}
      in questions addressed to constituents. The phrases should describe
      what the bill does, affects, or changes.

      Bill: #{bill_number} — #{title}
      Summary: #{summary}

      Questions needing phrases:
      #{questions_text}

      Extract as many relevant phrases as possible. Each phrase should be
      2-6 words. Focus on concrete subject matter, not procedural details.

      Good examples:
      - "environmental assessment thresholds"
      - "carbon pricing mechanism"
      - "school funding formula"
      - "workplace safety inspections"
      - "municipal zoning authority"

      Bad examples:
      - "this act" (too vague)
      - "the minister may" (procedural, not substantive)
      - "subsection 12(3)" (too specific, not meaningful)

      Respond with one phrase per line. No numbering, no bullets, no
      explanation.

      Phrases:
    PROMPT
    if extra_instruction
      base + "#{extra_instruction}\n"
    else
      base
    end
  end

  def bill_specific_question_generation(bill_number:, title:, summary:, position:, position_description:, verified_phrases:)
    phrases_text = verified_phrases.any? ? verified_phrases.map { |p| "- #{p}" }.join("\n") : "- (none available)"

    <<~PROMPT
      You are drafting intake questions for a constituent who #{position}s #{bill_number} — #{title}.
      #{position_description}
      The questions will appear on a form before the constituent writes a letter to their representative.
      Each question should invite a brief, personal answer and be clearly tied to a specific provision or effect of this bill.

      Bill summary:
      #{summary}

      Verified topics from the bill:
      #{phrases_text}

      Draft 3 distinct questions that a constituent who #{position}s this bill could answer.
      Make each question specific to this bill, not a generic political opinion prompt.
      Do not number the questions. Write one question per line.

      Questions:
    PROMPT
  end

  def question_selection(bill_number:, title:, summary:, category:, position:, questions_list:)
    <<~PROMPT
      You are selecting intake questions for a constituent writing to
      their representative about a bill. Pick the most relevant questions.

      Bill: #{bill_number} — #{title}
      Summary: #{summary}
      Category: #{category}
      Constituent position: #{position}

      Available questions:
      #{questions_list}

      Select the 3 most relevant questions for this bill and position.
      Prefer bill-specific questions when they are available.
      Consider the bill's specific subject matter when choosing.
      Ensure variety in question types and sources (don't pick all templates or all bill-specific questions).

      Respond with only the question IDs separated by commas. No other text.

      IDs:
    PROMPT
  end

  def phrase_matching(bill_number:, title:, phrases_list:, questions_list:)
    <<~PROMPT
      For each question below, select the 3 best phrases to substitute
      for {bill_subject}. Rank them from best (1) to third-best (3).

      Bill: #{bill_number} — #{title}

      Available phrases:
      #{phrases_list}

      Questions:
      #{questions_list}

      For each question, respond with the question number and the phrase
      numbers ranked best to third-best.
      Format: Q{number}=P{phrase_number},P{phrase_number},P{phrase_number}

      Example: Q1=P3,P7,P1

      Matches:
    PROMPT
  end

  def answer_relevance(question:, answer:)
    <<~PROMPT
      A constituent answered an intake question about a bill. Is their
      answer specific enough to include in a formal letter to their
      representative?

      Question: "#{question}"
      Answer: "#{answer}"

      "good" means the answer provides specific, usable detail.
      "vague" means the answer is too general, too short, or empty.

      Respond with only one word: "good" or "vague"

      Verdict:
    PROMPT
  end

  def answer_follow_up(question:, answer:)
    <<~PROMPT
      A constituent gave a vague answer to a question. Select the best
      follow-up question to prompt more detail.

      Original question: "#{question}"
      Vague answer: "#{answer}"

      Available follow-ups:
      1. Can you give a specific example?
      2. When did you first notice or experience this?
      3. Who else is affected by this that you know of?
      4. How has this affected your day-to-day?
      5. Why does this matter to you personally?

      Pick the one most likely to get a specific, useful answer.

      Respond with only the number. No other text.

      Number:
    PROMPT
  end

  def email_drafting_a(rep_title:, rep_name:, rep_riding:, is_minister:, ministry_name:, bill_number:, bill_title:, bill_origin:, position:, user_riding:, constituent_description:, qa_pairs:, position_config:)
    minister_line = if is_minister && ministry_name.present?
      "The representative is the Minister of #{ministry_name}."
    else
      ""
    end

    rep_last_name = rep_name.to_s.split.last

    <<~PROMPT
      Write a formal email from a constituent to their elected
      representative about a bill. Follow the structure exactly.

      REPRESENTATIVE: #{rep_title} #{rep_name}, #{rep_riding}
      #{minister_line}
      BILL: #{bill_number} — #{bill_title}
      ORIGINATED IN: #{bill_origin}
      POSITION: #{position_config[:position_description]}
      CONSTITUENT RIDING: #{user_riding}

      Structure — write each section's content after its description:

      OPENING:
      Write: "Dear #{rep_title} #{rep_last_name},"

      STATE_PURPOSE:
      Write exactly one sentence. State that you are #{constituent_description},
      you are writing about #{bill_number}, and you
      #{position_config[:position_verb]} it.

      PERSONAL_CONTEXT:
      Write 2-3 sentences using ONLY the details below. Do not add
      information the constituent did not provide.
      #{qa_pairs}

      SPECIFIC_CONCERN:
      Write 1-2 sentences about the most important aspect of this bill
      to the constituent, based on their answers above.

      CALL_TO_ACTION:
      Write one sentence asking #{rep_title} #{rep_last_name} to
      #{position_config[:action_based_on_position]} #{bill_number}.

      CLOSING:
      Write: "I would appreciate hearing your position on this matter."

      SIGN_OFF:
      Write: "Sincerely," then on separate lines: [YOUR_FULL_NAME] and
      [YOUR_ADDRESS]

      Rules:
      - Use [YOUR_FULL_NAME] and [YOUR_ADDRESS] as placeholders exactly
       as written
      - Do not invent facts, statistics, examples, or details the
       constituent did not provide
      - Do not include section labels in the output — write only the
       email text
      - Keep the total email under 300 words
      - Use formal but accessible language
      - If the representative is a minister, address them as
        "Minister #{rep_last_name}" after the opening
      - If the bill originated in the Senate, you may note this naturally
        (e.g., "Bill S-XX, which was introduced in the Senate"). Do not
        suggest the constituent write to a senator — route to their MP.
    PROMPT
  end

  def quality_bill_accuracy(email:, bill_number:, title:)
    <<~PROMPT
      Does this email correctly reference the bill?

      Email: "#{email}"
      Expected bill reference: #{bill_number} — #{title}

      The email should mention the bill number. The title does not need
      to be exact but should not be wrong.

      Respond with only: "pass" or "fail"

      Verdict:
    PROMPT
  end

  def quality_position_accuracy(email:, position:, position_verb:)
    <<~PROMPT
      Does this email correctly express the constituent's position?

      Email: "#{email}"
      Expected position: #{position}

      The email should clearly #{position_verb} the bill. If the position
      is unclear, contradictory, or wrong, fail.

      Respond with only: "pass" or "fail"

      Verdict:
    PROMPT
  end

  def quality_hallucination(email:, qa_pairs:, bill_number:, title:)
    <<~PROMPT
      Does this email contain claims or details the constituent did not
      provide?

      Email: "#{email}"

      Constituent's answers:
      #{qa_pairs}

      Bill information: #{bill_number} — #{title}

      Allowed: general connecting words, transitions, formal phrasing,
       references to the bill by number or title.
      Not allowed: specific facts, statistics, examples, anecdotes,
       or details not found in the answers or bill info.

      Respond with only: "pass" or "fail"

      Verdict:
    PROMPT
  end

  def quality_tone(email:)
    <<~PROMPT
      Is this email's tone appropriate for a formal communication to an
      elected representative?

      Email: "#{email}"

      Appropriate: formal, respectful, firm, clear.
      Inappropriate: aggressive, sarcastic, overly casual, threatening,
       or demanding.

      Respond with only: "pass" or "fail"

      Verdict:
    PROMPT
  end
end
