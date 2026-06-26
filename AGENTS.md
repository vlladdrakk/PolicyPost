# AGENTS.md

PolicyPost — a civic letter generator that helps Canadian constituents draft formal emails to their elected representatives about bills. Flow: postal code → reps → bill → position → intake questions → SLM-drafted email → edit/send.

## Repository state

- Rails 8.1 app (Ruby 3.2, SQLite, Minitest, importmap/Turbo/Stimulus, solid_queue/cache/cable). Generated with `--skip-git`, so this is **still not a git repo** — do not run git/commit unless explicitly asked.
- `spec.md` is the authoritative source of truth for architecture, data models, prompt contracts, and validation logic. If code conflicts with it, the spec wins unless explicitly superseded.
- OpenCode config: `opencode.json` (default agent `policypost`); agents in `.opencode/agent/` (`policypost` primary + subagents `data-pipeline`, `user-pipeline`, `adapter`, `review`, `security`).

## Developer commands

- Tests: `bin/rails db:test:prepare test`
- System tests: `bin/rails db:test:prepare test:system`
- Lint: `bin/rubocop -f github`
- Security: `bin/brakeman --no-pager`, `bin/bundler-audit`, `bin/importmap audit`
- Migrate: `bin/rails db:migrate`
- Run a single test: `bin/rails test test/models/bill_test.rb` (or `:line`)
- Console / runner: `bin/rails console`, `bin/rails runner '...'`

CI (`.github/workflows/ci.yml`) runs scan_ruby, scan_js, lint, test, system-test as separate jobs.

## Where things live

- `app/models/` — `Bill`, `BillPhrase`, `Question`, `BillQuestionSelection`, `QuestionPhrase`, `Representative`, `UserSession`, `IntakeAnswer`. `Question` has `source` (`template`/`generated`), `status` (`pending`/`approved`/`rejected`), and `bill_id` for generated questions.
- `app/models/concerns/domain_constants.rb` — `DomainConstants` (`CATEGORIES`, `POSITIONS`, `STATUSES`, `PROCESSING_STATUSES`, `DRAFTING_APPROACHES`, `VERDICTS`). The single source for the fixed enum-value lists; models `include DomainConstants`.
- `app/adapters/` — `BillAdapter` (abstract base), `RawBill` (value object), `FederalAdapter` (LEGISinfo skeleton). Autoloaded via `app/*`.
- `lib/policy_post/` — `Config` (`POSITION_CONFIG`, `DRAFTING_CONFIG`, `QUESTION_GENERATION_CONFIG`, `QUESTION_SELECTION_CONFIG`), `PhraseVerification` (`verify_phrases`, `select_phrases`), `EmailQuality` (`check_placeholders`, `check_length`, `process_quality_results`, `FAILURE_WARNINGS`). Autoloaded via `config.autoload_lib`.

## Architecture — the central fact

Two execution contexts that must not be conflated:

- **Data pipeline** (batch, at bill ingestion): pre-computes classification, key-phrase extraction, bill-specific question generation, question selection, and phrase–question matching. Results are stored and **reviewed before a bill goes live**. No LLM calls for these happen at session time.
- **User pipeline** (real-time, per session): answer-relevance checks, email drafting (Task 5), and quality checks (Task 6). Reads pre-computed data-pipeline outputs; never re-runs question preparation.

Flow: jurisdiction adapters → unified `RawBill` → SLM Tasks 1–1b–1c–2–3 (data) → review/approve → user session (Tasks 4–5–6).

## Spec is the contract — now translated to Ruby

`spec.md` contains concrete definitions intended as verbatim contract. They have been ported to Ruby (the spec's Python was illustrative of intent, not the implementation language):
- `BillAdapter` (abstract base, `NotImplementedError` methods) + `RawBill` (keyword-init value object) — `app/adapters/`. Every jurisdiction adapter implements `list_bills`, `fetch_bill`, `fetch_new_bills`, `normalize_status`.
- `verify_phrases`, `select_phrases` — `PolicyPost::PhraseVerification` (`lib/policy_post/phrase_verification.rb`).
- `check_placeholders`, `check_length`, `process_quality_results` — `PolicyPost::EmailQuality` (`lib/policy_post/email_quality.rb`).
- `POSITION_CONFIG`, `DRAFTING_CONFIG` — `PolicyPost::Config` (`lib/policy_post/config.rb`).

If you change behavior, confirm it still matches the spec's prompts, validation, and fallback chains.

## Domain rules that are easy to get wrong

- **Categories**: exactly 12 fixed (`healthcare, education, environment, housing, labour, tax, justice, transportation, indigenous, digital, social_services, governance`). Invalid → default `governance` + manual-review flag.
- **Positions**: `support`, `oppose`, `support_with_amendments`. Task 2 runs per position; adding a position means adding that combination.
- **Question count**: 2–3 intake questions per bill + position. Aim for 3; accept fewer if not enough good candidates exist.
- **Generated questions**: created at ingestion time (Task 1c), stored with `source: "generated"` and `status: "pending"`. Must be approved or rejected in review before the bill can go live. Approved generated questions are mixed with template questions during Task 2 selection.
- **Phrase verification is programmatic** (substring/fuzzy match against bill text), not an LLM call. `<3` verified phrases → one extraction retry → fall back to short title → then bill number.
- **Follow-ups**: max one per question, never re-checked for relevance; skip silently on "I don't know" or skip.
- **Email drafting**: two A/B approaches — A (single-pass scaffold) and B (4 incremental turns with per-turn validation). `DRAFTING_CONFIG.default_approach = "B"`; on A failure retry with B; B failure shows with warnings.
- **Quality checks (Task 6)**: 6 independent checks, all always run. Aggregation: 0 fail=pass · 1=pass_with_warning · 2=retry alternate drafting approach · 3+=show_with_warnings.
- **Placeholders** `[YOUR_FULL_NAME]` and `[YOUR_ADDRESS]` must appear verbatim in drafted emails. **Length limit**: 300 words.
- Phrase-selection strategy at runtime: start with `top_only` (rank 1); `round_robin`/`random` are future A/B.

## Canadian context

Jurisdictions are Canadian (federal, nb, on, bc, …). Federal adapter sources LEGISinfo at `parl.ca`. Bill number formats differ by jurisdiction (federal `C-XX`/`S-XX`, provincial `Bill NN`). Session strings look like "44th Parliament, 2nd Session" / "60th Legislature, 1st Session".
