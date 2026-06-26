This is the right level of rigour. Let me build both documents out properly.

### System Architecture Overview

```skill:mindmap
{
 "title": "Civic Letter Generator — System Architecture",
 "root": {
 "label": "System",
 "children": [
 {
 "label": "Data Pipeline",
 "children": [
 { "label": "Source Adapters" },
 { "label": "Unified Bill Ingestion" },
 { "label": "SLM Processing" },
 { "label": "Review & Approval" }
 ]
 },
 {
 "label": "SLM Pipeline",
 "children": [
 { "label": "Task 1: Classification" },
 { "label": "Task 1b: Phrase Extraction" },
 { "label": "Task 2: Question Selection" },
 { "label": "Task 3: Phrase-Question Matching" },
 { "label": "Task 4: Answer Relevance" },
 { "label": "Task 5: Email Drafting" },
 { "label": "Task 6: Quality Checks" }
 ]
 },
 {
 "label": "User Pipeline",
 "children": [
 { "label": "Postal Code → Reps" },
 { "label": "Bill Selection" },
 { "label": "Position & Intake" },
 { "label": "Email Generation" },
 { "label": "Edit & Send" }
 ]
 },
 {
 "label": "Review System",
 "children": [
 { "label": "Review UI" },
 { "label": "Manual Testing" },
 { "label": "Smoke Testing (future)" }
 ]
 }
 ]
 }
}
```

---

## Document 1: SLM Pipeline Specification

### Pipeline Overview

The SLM pipeline is split into two execution contexts:

**Data Pipeline** — runs at bill ingestion time. Pre-computes classification, phrase extraction, question selection, and phrase-question matching. Output is stored in the database and reviewed before bills go live.

**User Pipeline** — runs at session time. Processes user answers, drafts email, validates output. All data pipeline outputs are already available; no LLM calls needed for question preparation.

---

### Task 1: Bill Classification

**Context:** Data pipeline, batch
**Purpose:** Assign a primary category to the bill. Used to filter the question bank.
**Model requirement:** Any instruct-tuned SLM, 1B+ parameters

**Input:**
- Bill number
- Bill title
- Bill summary

**Prompt:**

```text
Classify this bill into exactly one category.

Bill: {bill_number} — {bill_title}
Summary: {bill_summary}

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
```

**Output:** Single category string

**Validation:**
- Strip whitespace, lowercase
- Check against the 12 allowed categories
- If invalid: retry once with the same prompt
- If still invalid: default to `governance`, flag for manual review

**Storage:** `bills.category` field

**Error handling:**
- Never raise an error that blocks the pipeline
- Log all raw outputs for analysis
- Track classification accuracy over time to refine prompts

---

### Task 1b: Key Phrase Extraction

**Context:** Data pipeline, batch
**Purpose:** Extract bill-specific phrases from the full bill text for use in question adaptation
**Model requirement:** Any instruct-tuned SLM, 1B+ parameters

**Input:**
- Bill number
- Bill title
- Bill summary
- Bill full text (or a chunked subset if too long)
- List of question templates that need `{bill_subject}` substitution

**Prompt:**

```text
Extract phrases from this bill that could replace {bill_subject}
in questions addressed to constituents. The phrases should describe
what the bill does, affects, or changes.

Bill: {bill_number} — {bill_title}
Summary: {bill_summary}

Questions needing phrases:
- {question_template_1}
- {question_template_2}
- {question_template_3}
-...

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
```

**Output:** List of phrases

**Validation — Phrase Verification Pass:**

Each extracted phrase must be verified against the bill's actual text. This is a programmatic check, not an LLM call.

```python
def verify_phrases(phrases: list[str], bill_text: str) -> list[str]:
 verified = []
 for phrase in phrases:
 # Normalize both strings for matching
 normalized_phrase = phrase.lower().strip()
 normalized_text = bill_text.lower()
 
 if normalized_phrase in normalized_text:
 verified.append(phrase)
 else:
 # Try fuzzy matching — allow minor word form differences
 # e.g., "assessments" vs "assessment"
 words = normalized_phrase.split()
 if all(any(word in normalized_text for word in words)):
 verified.append(phrase)
 # else: discard the phrase
 
 return verified
```

**Fallback:**
- If fewer than 3 phrases pass verification: re-run extraction once with added instruction "Ensure all phrases appear verbatim in the bill text."
- If still fewer than 3: use the bill's short title as a default phrase
- If no short title: use the bill number itself ("Bill 47")

**Storage:** `bill_phrases` table (see schema below)

---

### Task 1c: Bill-Specific Question Generation

**Context:** Data pipeline, batch
**Purpose:** Generate intake questions that are tightly grounded in this specific bill's provisions, not generic templates.
**Model requirement:** Any instruct-tuned SLM, 1B+ parameters

**Pre-computation strategy:** Run for every valid position option. Currently: `support`, `oppose`.

**Input:**
- Bill number, title, summary
- Verified phrases (from Task 1b)
- Position (support or oppose)

**Prompt:**

```text
You are drafting intake questions for a constituent who {position}s {bill_number} — {bill_title}.
{position_description}
The questions will appear on a form before the constituent writes a letter to their representative.
Each question should invite a brief, personal answer and be clearly tied to a specific provision or effect of this bill.

Bill summary:
{bill_summary}

Verified topics from the bill:
- {verified_phrase_1}
- {verified_phrase_2}
...

Draft 3 distinct questions that a constituent who {position}s this bill could answer.
Make each question specific to this bill, not a generic political opinion prompt.
Do not number the questions. Write one question per line.

Questions:
```

**Output:** One question per line.

**Validation:**
- Parse into non-empty lines ending in `?`.
- Drop duplicates and questions that are too similar to existing template questions.
- Drop questions that cannot be tied to the bill (must mention the bill number, short title, title words, or a verified phrase).
- Keep up to 3 valid candidates.
- If validation produces zero candidates, continue without bill-specific questions for this position.

**Review/approval:**
- Generated questions are stored with `source: "generated"`, `status: "pending"`.
- A reviewer must approve or reject each generated question before the bill can be approved.
- Approved generated questions become eligible for Task 2 selection.
- Rejected generated questions remain visible for audit but are never shown to users.

**Storage:** `questions` table, with `source`, `status`, and `bill_id` columns.

---

### Task 2: Question Selection

**Context:** Data pipeline, batch
**Purpose:** Select the best 2-3 intake questions for a given bill + position combination, mixing approved bill-specific questions with curated templates.
**Model requirement:** Any instruct-tuned SLM, 1B+ parameters

**Pre-computation strategy:** Run for every valid position option. Currently: `support`, `oppose`. If "it's complicated" is added as a position later, add that combination.

**Input:**
- Bill number, title, summary
- Category (from Task 1)
- Position (support or oppose)
- Template question bank (questions matching category + position with `source: "template"`)
- Approved generated questions for this bill + position (`source: "generated"`, `status: "approved"`)

**Prompt:**

```text
You are selecting intake questions for a constituent writing to
their representative about a bill. Pick the most relevant questions.

Bill: {bill_number} — {bill_title}
Summary: {bill_summary}
Category: {category}
Constituent position: {position}

Available questions:
{formatted_list_of_filtered_questions_with_ids_and_types}

Select the 3 most relevant questions for this bill and position.
Prefer bill-specific questions when they are available.
Consider the bill's specific subject matter when choosing.
Ensure variety in question types and sources (don't pick all templates or all bill-specific questions).

Respond with only the question IDs separated by commas. No other text.

IDs:
```

**Output:** Comma-separated list of question IDs

**Validation:**
- Parse IDs, strip whitespace
- Verify each ID exists in the candidate pool
- Verify 2-3 IDs returned (accept fewer if the candidate pool is smaller)
- Verify at least 2 different `type` values are represented
- Deduplicate selected questions after substitution
- If validation fails: retry once
- If still fails: use rule-based fallback (approved generated questions first, then templates by priority, up to 3)

**Storage:** `bill_question_selections` table — one row per bill + position combination

---

### Task 3: Phrase-Question Matching

**Context:** Data pipeline, batch
**Purpose:** For each selected question that has a `{bill_subject}` placeholder, select the best 3 phrases for substitution
**Model requirement:** Any instruct-tuned SLM, 1B+ parameters

**Input:**
- Bill number, title
- Verified phrases (from Task 1b)
- Selected questions (from Task 2)
- Only questions containing `{bill_subject}` need matching

**Prompt:**

```text
For each question below, select the 3 best phrases to substitute
for {bill_subject}. Rank them from best (1) to third-best (3).

Bill: {bill_number} — {bill_title}

Available phrases:
{numbered_list_of_verified_phrases}

Questions:
{numbered_list_of_questions_with_placeholders}

For each question, respond with the question number and the phrase
numbers ranked best to third-best.
Format: Q{number}=P{phrase_number},P{phrase_number},P{phrase_number}

Example: Q1=P3,P7,P1

Matches:
```

**Output:** Structured mapping like `Q1=P3,P7,P1`

**Validation:**
- Parse each mapping
- Verify phrase numbers exist in the provided list
- Verify exactly 3 phrases per question
- If a question has fewer than 3 valid phrase matches, fill remaining slots with the bill's short title
- If parsing fails entirely: assign the top 3 phrases (by order in the list) to every question as a fallback

**Storage:** `question_phrases` table — one row per question + phrase + rank

**Runtime phrase selection:**

When the user session selects which questions to display, the phrase used for each question is determined by an algorithm:

```python
def select_phrases(questions: list[QuestionWithPhrases], 
 session_id: str) -> dict[str, str]:
 """
 Select one phrase per question for this session.
 
 Strategies (configurable):
 - round_robin: Cycle through rank 1, 2, 3 across sessions
 - random: Pick randomly weighted by rank
 - top_only: Always use rank 1 (simplest, most reliable)
 """
 selections = {}
 
 for i, q in enumerate(questions):
 if q.phrases:
 if strategy == "round_robin":
 # Use session counter to rotate through ranks
 rank_index = (session_counter + i) % len(q.phrases)
 selections[q.id] = q.phrases[rank_index].text
 elif strategy == "random":
 # Weighted random: rank 1 = 60%, rank 2 = 25%, rank 3 = 15%
 selections[q.id] = weighted_random_choice(q.phrases)
 elif strategy == "top_only":
 selections[q.id] = q.phrases[0].text # rank 1
 else:
 selections[q.id] = bill.short_title or bill.bill_number
 
 return selections
```

Start with `top_only` for simplicity. Rotate strategies as a future A/B test.

---

### Task 4: Answer Relevance Check

**Context:** User pipeline, real-time
**Purpose:** Determine if a user's answer is substantive enough to use in the email, or if a follow-up is needed
**Model requirement:** Any instruct-tuned SLM, 1B+ parameters

**Primary check prompt:**

```text
A constituent answered an intake question about a bill. Is their
answer specific enough to include in a formal letter to their
representative?

Question: "{adapted_question}"
Answer: "{user_answer}"

"good" means the answer provides specific, usable detail.
"vague" means the answer is too general, too short, or empty.

Respond with only one word: "good" or "vague"

Verdict:
```

**Output:** `good` or `vague`

**Validation:**
- Strip whitespace, lowercase
- If output is neither "good" nor "vague": treat as "good" (err on the side of not pestering the user)

**Follow-up selection (when verdict = "vague"):**

Primary: SLM selection from the generic follow-up bank.

```text
A constituent gave a vague answer to a question. Select the best
follow-up question to prompt more detail.

Original question: "{adapted_question}"
Vague answer: "{user_answer}"

Available follow-ups:
1. Can you give a specific example?
2. When did you first notice or experience this?
3. Who else is affected by this that you know of?
4. How has this affected your day-to-day?
5. Why does this matter to you personally?

Pick the one most likely to get a specific, useful answer.

Respond with only the number. No other text.

Number:
```

**Fallback:** If SLM selection fails or returns invalid output, use "Can you give a specific example?" as the default follow-up.

**Behaviour rules:**
- Only one follow-up per question. No loops.
- Follow-up answers are never re-checked for relevance
- If the user skips a question or answers "I don't know," move on without follow-up

---

### Task 5: Email Drafting

**Context:** User pipeline, real-time
**Purpose:** Generate the constituent email
**Model requirement:** Any instruct-tuned SLM, 1B+ parameters

Both approaches are implemented. A/B testing determines the default. The user can also manually select an approach via Advanced Configuration.

**Common inputs for both approaches:**
- Representative: title, name, riding, is_minister flag
- Bill: number, title, category
- Position: support / oppose / support_with_amendments
- Constituent riding
- Intake Q&A pairs
- Verified phrases (for reference, to avoid hallucinating bill details)

---

**Approach A: Single-Pass Scaffold**

One LLM call. The full email structure is provided as a scaffold. The model fills in each section.

**Prompt:**

```text
Write a formal email from a constituent to their elected
representative about a bill. Follow the structure exactly.

REPRESENTATIVE: {rep_title} {rep_name}, {rep_riding}
{is_minister: The representative is the Minister of {ministry_name}.}
BILL: {bill_number} — {bill_title}
POSITION: {position_description}
CONSTITUENT RIDING: {user_riding}

Structure — write each section's content after its description:

OPENING:
Write: "Dear {rep_title} {rep_last_name},"

STATE_PURPOSE:
Write exactly one sentence. State that you are a constituent of
{user_riding}, you are writing about {bill_number}, and you
{position_verb} it.

PERSONAL_CONTEXT:
Write 2-3 sentences using ONLY the details below. Do not add
information the constituent did not provide.
{formatted_qa_pairs}

SPECIFIC_CONCERN:
Write 1-2 sentences about the most important aspect of this bill
to the constituent, based on their answers above.

CALL_TO_ACTION:
Write one sentence asking {rep_title} {rep_last_name} to
{action_based_on_position} {bill_number}.

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
 "Minister {last_name}" after the opening
```

**Position-specific variables:**

```python
POSITION_CONFIG = {
 "support": {
 "position_description": "The constituent supports this bill.",
 "position_verb": "support",
 "action_based_on_position": "vote for"
 },
 "oppose": {
 "position_description": "The constituent opposes this bill.",
 "position_verb": "oppose",
 "action_based_on_position": "vote against"
 },
 "support_with_amendments": {
 "position_description": "The constituent supports this bill "
 "with amendments.",
 "position_verb": "support with amendments to",
 "action_based_on_position": "propose amendments to"
 }
}
```

**Output:** Full email text

**Validation:** Passes to Task 6 quality checks

---

**Approach B: Incremental Section Generation**

Four sequential LLM calls. Each call generates one section and sees only the previously completed sections plus its own instructions.

**Turn 1 — OPENING + STATE_PURPOSE**

```text
Write the opening of a formal email from a constituent to their
elected representative about a bill.

REPRESENTATIVE: {rep_title} {rep_name}, {rep_riding}
{is_minister: The representative is the Minister of {ministry_name}.}
BILL: {bill_number} — {bill_title}
POSITION: {position_description}
CONSTITUENT RIDING: {user_riding}

Write exactly:
1. "Dear {rep_title_or_minister} {rep_last_name},"
2. One sentence stating you are a constituent of {user_riding},
 writing about {bill_number}, and you {position_verb} it.

Write only the email text. No labels, no explanation.
```

**Per-turn validation (after Turn 1):**

```text
Does this text correctly state the bill number {bill_number} and
the constituent's position ({position})?

Text: "{generated_text}"

Respond with only: "clean" or "error"

Verdict:
```

If "error": re-run Turn 1 once with added instruction "Use ONLY the exact bill number and position provided." If still error: proceed anyway, Task 6 will catch it.

**Turn 2 — PERSONAL_CONTEXT**

```text
Continue this email. Write the PERSONAL_CONTEXT section only.

So far:
"""
{email_text_so_far}
"""

Write 2-3 sentences using ONLY these details from the constituent.
Do not add information they did not provide. Do not repeat what was
already stated in the email.

{formatted_qa_pairs}

Write only the new sentences. No labels, no explanation.
```

**Per-turn validation (after Turn 2):**

```text
Does this text contain any specific facts, statistics, examples,
or details NOT found in the constituent's answers?

Constituent answers:
{formatted_qa_pairs}

Text: "{generated_text}"

General connecting words and transitions are fine. Only flag
invented substantive claims.

Respond with only: "clean" or "hallucinated"

Verdict:
```

If "hallucinated": re-run Turn 2 once with "Use ONLY the information in the answers. Do not add any details, examples, or statistics." If still hallucinated: proceed, Task 6 will flag it.

**Turn 3 — SPECIFIC_CONCERN**

```text
Continue this email. Write the SPECIFIC_CONCERN section only.

So far:
"""
{email_text_so_far}
"""

Write 1-2 sentences about the constituent's most important concern
regarding {bill_number}. Base this on their answers. Do not
introduce new information.

Write only the new sentences. No labels, no explanation.
```

**Per-turn validation (after Turn 3):** Same hallucination check as Turn 2.

**Turn 4 — CALL_TO_ACTION + CLOSING + SIGN_OFF**

```text
Continue this email. Write the final three sections.

So far:
"""
{email_text_so_far}
"""

Write:
1. One sentence asking {rep_title} {rep_last_name} to
 {action_based_on_position} {bill_number}.
2. "I would appreciate hearing your position on this matter."
3. "Sincerely," then on the next line [YOUR_FULL_NAME] and on the
 next line [YOUR_ADDRESS]

Write only the new text. No labels, no explanation.
```

**Per-turn validation (after Turn 4):**

```text
Does this text contain the placeholders [YOUR_FULL_NAME] and
[YOUR_ADDRESS]?

Text: "{generated_text}"

Respond with only: "clean" or "missing_placeholders"

Verdict:
```

If "missing_placeholders": programmatically insert them.

---

**A/B Test Configuration:**

```python
DRAFTING_CONFIG = {
 "default_approach": "B", # Change based on test results
 "ab_test": {
 "enabled": True,
 "traffic_split": {"A": 0.5, "B": 0.5},
 "tracking_key": "drafting_approach"
 },
 "fallback": {
 # If Approach A fails quality checks, retry with B
 "A_failure_retry_with": "B",
 "B_failure_retry_with": None # Show with warnings
 }
}
```

---

### Task 6: Quality Checks

**Context:** User pipeline, real-time
**Purpose:** Validate the generated email before presenting it to the user
**Model requirement:** Any instruct-tuned SLM, 1B+ parameters

Each check is an independent prompt. All checks run regardless of individual results. Results are aggregated.

**Check 1 — Bill Accuracy**

```text
Does this email correctly reference the bill?

Email: "{full_email_text}"
Expected bill reference: {bill_number} — {bill_title}

The email should mention the bill number. The title does not need
to be exact but should not be wrong.

Respond with only: "pass" or "fail"

Verdict:
```

**Check 2 — Position Accuracy**

```text
Does this email correctly express the constituent's position?

Email: "{full_email_text}"
Expected position: {position}

The email should clearly {position_verb} the bill. If the position
is unclear, contradictory, or wrong, fail.

Respond with only: "pass" or "fail"

Verdict:
```

**Check 3 — Hallucination Check**

```text
Does this email contain claims or details the constituent did not
provide?

Email: "{full_email_text}"

Constituent's answers:
{formatted_qa_pairs}

Bill information: {bill_number} — {bill_title}

Allowed: general connecting words, transitions, formal phrasing,
 references to the bill by number or title.
Not allowed: specific facts, statistics, examples, anecdotes,
 or details not found in the answers or bill info.

Respond with only: "pass" or "fail"

Verdict:
```

**Check 4 — Placeholder Check**

Programmatic, no LLM call.

```python
def check_placeholders(email_text: str) -> bool:
 return "[YOUR_FULL_NAME]" in email_text and "[YOUR_ADDRESS]" in email_text
```

**Check 5 — Tone Check**

```text
Is this email's tone appropriate for a formal communication to an
elected representative?

Email: "{full_email_text}"

Appropriate: formal, respectful, firm, clear.
Inappropriate: aggressive, sarcastic, overly casual, threatening,
 or demanding.

Respond with only: "pass" or "fail"

Verdict:
```

**Check 6 — Length Check**

Programmatic, no LLM call.

```python
def check_length(email_text: str, max_words: int = 300) -> bool:
 return len(email_text.split()) <= max_words
```

**Result aggregation:**

```python
def process_quality_results(results: dict) -> EmailQualityReport:
 failures = [name for name, passed in results.items() if not passed]
 
 if not failures:
 return EmailQualityReport(status="pass", warnings=[])
 
 if len(failures) == 1:
 # Single failure — show email with specific warning
 warning = FAILURE_WARNINGS[failures[0]]
 return EmailQualityReport(status="pass_with_warning", 
 warnings=[warning])
 
 if len(failures) <= 2:
 # Two failures — attempt one retry with the alternate approach
 return EmailQualityReport(status="retry", 
 retry_approach=alternate_approach)
 
 # 3+ failures — show email with all warnings, let user fix
 warnings = [FAILURE_WARNINGS[f] for f in failures]
 return EmailQualityReport(status="show_with_warnings", 
 warnings=warnings)

FAILURE_WARNINGS = {
 "bill_accuracy": "The bill reference may be incorrect — "
 "please verify before sending.",
 "position_accuracy": "The position expressed may not match "
 "your intent — please review.",
 "hallucination": "Some details may not reflect your answers — "
 "please verify the content is accurate.",
 "placeholder": "Personal detail placeholders are missing — "
 "add your name and address.",
 "tone": "The tone may not be appropriate — please review "
 "for formality.",
 "length": "The email is over 300 words — consider trimming."
}
```

---

### SLM Pipeline Call Budget

```skill:table
{
 "title": "SLM Call Budget",
 "columns": [
 { "key": "task", "label": "Task" },
 { "key": "context", "label": "Context" },
 { "key": "calls_per_unit", "label": "Calls Per Unit" },
 { "key": "unit", "label": "Unit" },
 { "key": "notes", "label": "Notes" }
 ],
 "rows": [
 { "task": "1: Classification", "context": "Data pipeline", "calls_per_unit": "1-2", "unit": "bill", "notes": "Retry on invalid output" },
 { "task": "1b: Phrase Extraction", "context": "Data pipeline", "calls_per_unit": "1-2", "unit": "bill", "notes": "Retry if <3 verified phrases" },
 { "task": "2: Question Selection", "context": "Data pipeline", "calls_per_unit": "2-4", "unit": "bill", "notes": "2 positions now, 3 if complicated added" },
 { "task": "3: Phrase-Question Matching", "context": "Data pipeline", "calls_per_unit": "2-4", "unit": "bill", "notes": "One per position" },
 { "task": "4: Answer Relevance", "context": "User pipeline", "calls_per_unit": "4-8", "unit": "session", "notes": "1 check + 1 follow-up selection per vague answer" },
 { "task": "5: Drafting (A)", "context": "User pipeline", "calls_per_unit": "1", "unit": "session", "notes": "Single pass" },
 { "task": "5: Drafting (B)", "context": "User pipeline", "calls_per_unit": "4-8", "unit": "session", "notes": "4 turns + up to 4 per-turn validations" },
 { "task": "6: Quality Checks", "context": "User pipeline", "calls_per_unit": "4", "unit": "session", "notes": "4 LLM checks + 2 programmatic" }
 ],
 "sortable": true
}
```

**Totals per session (assuming Approach B, worst case):**
- Data pipeline: 0 calls (pre-computed)
- Task 4: up to 8 calls
- Task 5: up to 8 calls
- Task 6: 4 calls
- **Maximum: ~20 calls per session**
- **Typical: ~12-15 calls per session**

At 1-4B model sizes, this is extremely affordable even at scale.

---

## Document 2: Bill Ingestion Pipeline

### Unified Bill Structure

```skill:table
{
 "title": "Unified Bill Data Model",
 "columns": [
 { "key": "field", "label": "Field" },
 { "key": "type", "label": "Type" },
 { "key": "source", "label": "Source" },
 { "key": "required", "label": "Required" },
 { "key": "notes", "label": "Notes" }
 ],
 "rows": [
 { "field": "id", "type": "UUID", "source": "Generated", "required": "Yes", "notes": "Internal primary key" },
 { "field": "jurisdiction", "type": "enum", "source": "Adapter", "required": "Yes", "notes": "federal, nb, on, bc, etc." },
 { "field": "legislature_session", "type": "string", "source": "Adapter", "required": "Yes", "notes": "e.g. '44th Parliament, 2nd Session' or '60th Legislature, 1st Session'" },
 { "field": "bill_number", "type": "string", "source": "Adapter", "required": "Yes", "notes": "e.g. 'C-47', 'Bill 21'" },
 { "field": "bill_type", "type": "enum", "source": "Adapter", "required": "No", "notes": "government, private_member, senate_public, etc." },
 { "field": "title", "type": "text", "source": "Adapter", "required": "Yes", "notes": "Full title" },
 { "field": "short_title", "type": "string", "source": "Adapter", "required": "No", "notes": "e.g. 'Impact Assessment Act'" },
 { "field": "summary", "type": "text", "source": "Adapter", "required": "Yes", "notes": "Legislative summary" },
 { "field": "sponsor_name", "type": "string", "source": "Adapter", "required": "No", "notes": "" },
 { "field": "sponsor_riding", "type": "string", "source": "Adapter", "required": "No", "notes": "" },
 { "field": "sponsor_party", "type": "string", "source": "Adapter", "required": "No", "notes": "" },
 { "field": "status", "type": "enum", "source": "Adapter", "required": "Yes", "notes": "introduced, first_reading, second_reading, committee, third_reading, royal_assent, defeated" },
 { "field": "introduced_date", "type": "date", "source": "Adapter", "required": "No", "notes": "" },
 { "field": "last_updated_date", "type": "date", "source": "Adapter", "required": "No", "notes": "" },
 { "field": "full_text_url", "type": "url", "source": "Adapter", "required": "Yes", "notes": "Link to official text" },
 { "field": "full_text", "type": "text", "source": "Adapter", "required": "No", "notes": "Scraped full text for phrase extraction" },
 { "field": "source_url", "type": "url", "source": "Adapter", "required": "Yes", "notes": "Link to the bill's page on the legislature site" },
 { "field": "source_id", "type": "string", "source": "Adapter", "required": "Yes", "notes": "ID from the source system, for deduplication" },
 { "field": "category", "type": "enum", "source": "SLM Task 1", "required": "Yes", "notes": "After SLM processing" },
 { "field": "processing_status", "type": "enum", "source": "Pipeline", "required": "Yes", "notes": "pending, processing, review, approved, rejected" },
 { "field": "created_at", "type": "timestamp", "source": "Generated", "required": "Yes", "notes": "" },
 { "field": "updated_at", "type": "timestamp", "source": "Generated", "required": "Yes", "notes": "" }
 ],
 "sortable": true
}
```

---

### Adapter Interface

Each jurisdiction gets an adapter that implements a common interface. The adapter handles all the messiness of the source system and returns clean, unified data.

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import date
from typing import Optional

@dataclass
class RawBill:
 """Unified bill structure returned by every adapter."""
 jurisdiction: str # "federal", "nb", "on", etc.
 legislature_session: str
 bill_number: str
 bill_type: Optional[str] # "government", "private_member", etc.
 title: str
 short_title: Optional[str]
 summary: str
 sponsor_name: Optional[str]
 sponsor_riding: Optional[str]
 sponsor_party: Optional[str]
 status: str # Unified status enum value
 introduced_date: Optional[date]
 last_updated_date: Optional[date]
 full_text_url: str
 full_text: Optional[str] # Scraped text for phrase extraction
 source_url: str
 source_id: str # For deduplication


class BillAdapter(ABC):
 """Base adapter interface for bill data sources."""
 
 @abstractmethod
 def list_bills(self, session: Optional[str] = None) -> list[str]:
 """Return source_ids for all bills, optionally filtered by session."""
 pass
 
 @abstractmethod
 def fetch_bill(self, source_id: str) -> RawBill:
 """Fetch a single bill by its source ID."""
 pass
 
 @abstractmethod
 def fetch_new_bills(self, since: Optional[date] = None) -> list[RawBill]:
 """Fetch bills added or updated since the given date."""
 pass
 
 @abstractmethod
 def normalize_status(self, raw_status: str) -> str:
 """Map source-specific status to unified status enum."""
 pass
```

**Adapter implementations:**

```text
Federal Adapter (LEGISinfo)
├── Source: https://www.parl.ca/LegisInfo/
├── Method: HTTP scraping + structured data extraction
├── Bill number format: C-XX, S-XX

