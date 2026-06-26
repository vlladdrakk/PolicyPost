# PolicyPost Feature Roadmap

> **Last updated:** 2026-06-26 — Personal context choice added to v2 roadmap; DraftGenerationJob shipped earlier today.  
> **Test status:** 163 tests, 0 failures, 0 errors.

---

## Project State Summary

**Tier** | **Status** | **Notes**
---|---|---
Data layer (8 tables, models, validations) | ✅ **Complete** | All migrations, models, associations, scopes, domain constants
Data pipeline (Tasks 1–1b–1c–2–3) | ✅ **Complete** | Classification, phrase extraction (with verification), bill-specific question generation, question selection, phrase matching. All wired in `BillProcessingJob` via Solid Queue
Review & approval UI | ✅ **Complete** | List/filter by status, show phrases + questions per position, add/remove phrases & questions, approve/reject with notes, generated question approval
User pipeline controller flow | ✅ **Complete** | Postal code → bill → position → intake → draft → edit. Routes, views, and sessions controller all wired end-to-end
Task 4 (answer relevance + follow-ups) | ✅ **Complete** | SLM-based verdict with follow-up selection. Skips on "I don't know". Max one follow-up per question
Task 5 Approach A (single-pass) | ✅ **Complete** | Full prompt, SLM call, email generation
Task 6 (all 6 quality checks) | ✅ **Complete** | 4 LLM checks + 2 programmatic. Aggregation logic matches spec (`pass` / `pass_with_warning` / `retry` / `show_with_warnings`)
Federal adapter (LEGISinfo) | ✅ **Complete** | JSON list + text scraper, status normalization, `list_bills`/`fetch_bill`/`fetch_new_bills`
Review UI — robust | ✅ **Complete** | Shows matched phrases per question, category overrides, add/remove phrases & questions dynamically
Minister handling in email | ✅ **Complete** | Prompt includes `is_minister`/`ministry_name`, addressing as "Minister {last}" after opening
SLM client + prompts module | ✅ **Complete** | Real HTTP client, `FakeSlmClient` for tests, all 16 prompts in `Prompts` module
Stimulus polling controller | ✅ **Complete** | Async draft generation with polling, spinner, error handling, auto-redirect after answer check
CI/CD pipeline | ✅ **Complete** | 5 CI jobs: scan_ruby, scan_js, lint, test, system-test. Dependabot configured
A/B test configuration | ⚠️ **Config exists, not wired** | `DRAFTING_CONFIG` defines traffic split & tracking key, but runtime always uses Approach A
Task 5 Approach B (incremental) | ❌ **Not implemented** | No prompts, no module, no per-turn validation. The biggest gap vs. spec
Fallback chain (A→B retry) | ❌ **Not implemented** | Config defines it but `draft_data` never retries; always single-pass
Background drafting job | ✅ **Complete** | `DraftGenerationJob` fires async via Solid Queue; polling controller checks status
Provincial adapters | ❌ **Not implemented** | Only federal adapter exists
Full test coverage | ⚠️ **Partial** | 25 test files, 163 tests. Missing: integration tests. Controller tests added for sessions + bills

---

## MVP — "It works end to end" (Current focus)

A constituent can enter their postal code, pick a bill, take a position, answer intake questions, receive a draft email, edit it, and send it.

| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | **Federal adapter** | ✅ Complete | LEGISinfo JSON + text scraping, status normalization |
| 2 | **Data pipeline jobs** | ✅ Complete | Tasks 1–1b–2–3 wired through `BillProcessingJob` |
| 3 | **Phrase verification** | ✅ Complete | Programmatic substring/fuzzy match in `PhraseVerification` |
| 4 | **Review/approval UI** | ✅ Complete | List, show, approve/reject, phrase/question management |
| 5 | **User flow controllers + routes** | ✅ Complete | Full 8-step flow in `SessionsController` |
| 6 | **Representative seeding** | ✅ Complete | Ottawa Centre / MP Mona Fortier / K1P1A4 |
| 7 | **Question bank** | ✅ Complete | Refreshed template bank + bill-specific generated questions approved in review |
| 8 | **Task 4 (answer relevance)** | ✅ Complete | SLM verdict + follow-up selection |
| 9 | **Task 5 Approach A** | ✅ Complete | Single-pass email drafting |
| 10 | **Task 6 quality checks** | ✅ Complete | All 6 checks (4 LLM + 2 programmatic) |
| 11 | **Basic views** | ✅ Complete | New session, bill selection, position, questions, draft, edit |
| 12 | **Edit screen** | ✅ Complete | Name/address fields + email body editing |
| 13 | **Proper representative titles** | ❌ Not started | `display_name` is bare `title + name`. Should include honorifics: "The Honourable" for ministers, proper MP styling |
| 14 | **Draft warnings in yellow** | ❌ Not started | Quality warnings render as red `flash alert` in `polling_controller.js:135`. Should render as yellow `flash warning` — mistakes are informational, not errors |
| 15 | **Admin Authentication** | ❌ Not started | Add a login screen and block access to /jobs and /admin to only logged in admin users |

**Exit criteria:** A user can complete the full flow from postal code to a usable draft email with at least one bill from one jurisdiction. → ✅ **Achieved** (verified by passing system tests)

---

## v2 — "Fully featured" (Next up)

Everything the spec describes, production-ready.

| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | **Task 5 Approach B** | ❌ Not started | 4-turn incremental drafting with per-turn validation. Needs: prompts (5 new), `EmailDrafting::ApproachB` module, per-turn validation logic, per-turn validation prompts (3 new) |
| 2 | **All 6 quality checks** | ✅ Complete | Already done — 4 LLM + 2 programmatic |
| 3 | **A/B prompt testing** | ❌ Not started | Allow for A/B testing of different prompts in the user flow and review flow. Support using examples created by users and some seeded examples. This allows us to finetune prompts #analytics_project# |
| 4 | **Fallback chain** | ❌ Not started | A fails → retry B; B fails → show with warnings. Needs: Approach B first, then retry loop in `draft_data` |
| 5 | **Provincial adapters** | ❌ Not started | Ontario, British Columbia, New Brunswick. Each needs: adapter class, bill-number format, scraping source |
| 6 | **Minister handling** | ✅ Complete | Already handled in prompts + email drafting |
| 7 | **Interactive UX** | ✅ Complete | Stimulus polling controller, Turbo, spinner states |
| 8 | **Full test coverage** | ⚠️ Partial | 163 tests pass. Missing: integration tests, more edge-case coverage for lib modules. Controller tests now exist (sessions + bills) |
| 9 | **Robust review UI** | ✅ Complete | Phrases, questions, matches, category, approve/reject all shown |
| 10 | **Processing step visibility** | ❌ Not started | Add `processing_step` column to bills, update `BillProcessingJob` to set it before each phase, surface in review dashboard (stat cards + table rows) |
| 11 | **CI/CD pipeline** | ✅ Complete | 5 jobs in CI, dependabot active |
| 12 | **LLM Stats Tracking** | ❌ **Not implemented** | Record context usage, response times, prefill time, prefill speed, token generation time and token generation speed #analytics_project# |
| 13 | **Personal context choice** | ❌ **Not started** | After intake answers pass, user chooses: skip (generic draft), structured prompting (questions 1-at-a-time w/ skip + final freeform), or freeform input (single textarea). Three distinct entrypoints to the draft page with unique prompts |

**Exit criteria:** The system matches the spec in full. Four jurisdictions supported. Both drafting approaches work with A/B testing and fallback. All quality checks active. Personal context choice integrated with unique prompts per path. Tests cover the critical paths.

---

## v3 — "Nice to haves"

Features that improve the product but aren't needed for it to work well.

| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | **"It's complicated" position** | ✅ Prepped | `support_with_amendments` defined in `DomainConstants` & `POSITION_CONFIG`. Need to: add to position UI, run Task 2/3 for this combo |
| 2 | **Phrase selection strategies** | ✅ Prepped | `select_phrases` supports `round_robin` and `random`. Only `top_only` used at runtime |
| 3 | **All Canadian jurisdictions** | ❌ Not started | QC, AB, SK, MB, NS, PEI, NL, YT, NT, NU |
| 4 | **User accounts** | ❌ Not started | Save draft history, revisit past emails, track sent letters |
| 5 | **Trending Bills** | ❌ Not started | Track mentions of bills in news rss feeds and show on main page. Also integrate PolicyPost trends |
| 6 | **Real postal code API** | ❌ Not started | Live riding lookup instead of seeded mapping |
| 7 | **Analytics dashboard** | ❌ Not started | Classification accuracy, A/B results, usage metrics |
| 8 | **Advanced configuration** | ❌ Not started | Let users manually select drafting approach, tone preferences |
| 9 | **Bill search & filter** | ❌ Not started | Search by keyword, filter by category/status/jurisdiction |
| 10 | **Multi-bill emails** | ❌ Not started | Draft a single email addressing multiple bills |
| 11 | **PWA features** | ❌ Not started | Offline support, installable app (manifest commented out) |
| 12 | **Smoke testing automation** | ❌ Not started | Automated end-to-end test of the full pipeline |
| 13 | **Social sharing** | ❌ Not started | Share your letter (anonymized) or encourage others to write |
| 14 | **Email templates / saved positions** | ❌ Not started | Pre-fill common personal contexts |
| 15 | **Representative response tracking** | ❌ Not started | Log whether/when reps reply |
| 16 | **Custom Campaigns** | ❌ Not started | Option for custom pages with preconfigured position and questions for orgs to send in email campaigns or something |

---

## Incomplete Items Detail (for your review)

These are the gaps found in the audit. Most are in the v2 → MVP overlap zone.

### 1. Task 5 Approach B — Not implemented ❌
**Files missing:**
- `lib/policy_post/user_pipeline/email_drafting_b.rb` (or inline in existing)
- 5 new prompts in `lib/policy_post/prompts.rb`: `email_drafting_b_turn1`, `email_drafting_b_turn2`, `email_drafting_b_turn3`, `email_drafting_b_turn4`, plus per-turn validations (3 prompts: turn1 validate position, turn2/3 validate hallucination, turn4 validate placeholders)
- Tests: `test/lib/policy_post/user_pipeline/email_drafting_b_test.rb`

**What it needs to do (per spec):**
- 4 sequential SLM calls with per-turn validation
- Turn 1: OPENING + STATE_PURPOSE (validate bill number + position)
- Turn 2: PERSONAL_CONTEXT (validate no hallucination)
- Turn 3: SPECIFIC_CONCERN (validate no hallucination)
- Turn 4: CALL_TO_ACTION + CLOSING + SIGN_OFF (validate placeholders present)
- On any validation failure: retry once with extra instruction, then proceed anyway

### 2. A/B routing and fallback chain — Not wired ❌
**Affected files:**
- `app/controllers/sessions_controller.rb` (`draft_data` action hardcodes approach "A")

**What needs to change:**
- Route to Approach A or B based on `DRAFTING_CONFIG.dig(:ab_test, :traffic_split)` (or session-based assignment)
- On Approach A quality failure with 2 failures → retry with Approach B
- On Approach B quality failure with 2 failures → show with warnings (per `b_failure_retry_with: nil`)
- The `drafting_approach` field on `ConstituentLetter` should reflect the actual approach used

### 3. Synchronous drafting in controller — Now async ✅
**Resolution:** `DraftGenerationJob` is implemented and wired. `draft_data` in `SessionsController` fires `DraftGenerationJob.perform_later`; the polling controller checks job status. Solid Queue handles the async execution.

### 4. Provincial adapters — Not started ❌
Only `FederalAdapter` exists. The three target provinces (ON, BC, NB) need:
- Adapter class inheriting `BillAdapter`
- Source URL + scraping logic
- Bill-number format handling
- Session string parsing
- Status normalization
- Tests

### 5. Personal context choice — Not started ❌

**Where it fits in the flow:**
```
postal code → bill → position → intake answers → answer relevance check
                                                       ↓
                                         [PERSONAL CONTEXT CHOICE]  ← NEW
                                         /         |          \
                                     skip      structured    freeform
                                       ↓           ↓            ↓
                                    draft      draft        draft
                                   (generic)  (prompted)   (freeform)
```

**Three paths, three prompts:**

1. **Skip — generic draft** *(fast path)*
   - User clicks "Skip — generate a generic letter" → straight to `show_draft`
   - Prompt uses only intake answers + bill context; no personal anecdote injected

2. **Structured prompting** *(guided path)*
   - Questions presented one at a time (user can skip any)
   - Final question is a semi-freeform: "Is there anything you'd like to change about how this letter is drafted?"
   - On completion → `show_draft`
   - Prompt weaves structured answers into the personal-context section of the draft

3. **Freeform input** *(open path)*
   - Single textarea: "Tell us anything you'd like your representative to know"
   - User can write as much or as little as they want
   - On submit → `show_draft`
   - Prompt injects the freeform text directly into the personal-context section

**What's needed:**
- **Controller**: new `edit_personal_context` + `update_personal_context` actions in `SessionsController`
- **Routes**: new routes for the personal context step
- **Views**: choice screen (`edit_personal_context`), structured-question screens (reuse question UI patterns), freeform textarea
- **Prompts**: 3 new drafting prompts (skip-generic, structured, freeform) — each constructs the personal-context section differently
- **Model**: `personal_context_mode` + `personal_context_data` columns on `ConstituentLetter` (or a new `PersonalContext` model)
- **Tests**: controller tests for all 3 paths, integration test for full flow

### 6. Test coverage gaps ⚠️
**Missing:**
- `test/integration/` — No integration tests (`.keep` only)
- `test/system/review_bills_test.rb` — Exists but hasn't been audited for completeness
- `test/lib/policy_post/` — Could use more edge-case coverage (phrase verification edge cases, config defaults, phrase selection strategies)

**Now present (since last audit):**
- `test/controllers/sessions_controller_test.rb` — 63 lines, user flow coverage
- `test/controllers/bills_controller_test.rb` — bills controller tests
- `test/jobs/draft_generation_job_test.rb` — async job tests

### 7. Minor observations
- **Approach mismatch:** `ConstituentLetter.drafting_approach` defaults to `"B"` but `EmailDraft` is always created with `approach: "A"` — these should agree
- **Postal code validation:** No format validation on `PostalCode.code` (could enforce Canadian `A#A #A#` format)
- **Lib tasks directory:** `lib/policy_post/tasks/` exists but is empty and excluded from autoload — could be cleaned up
- **Follow-up partial unused:** `app/views/sessions/_follow_up.html.erb` exists but isn't rendered anywhere (follow-up UI is inline in `show_questions.html.erb`)

---

## Dependency Order

```
Federal adapter → Data pipeline jobs → Review UI → User flow → Approach A → MVP ✅
                                                                         ↓
Approach B ───────────────────────────────────────────────────────────── v2
Provincial adapters → A/B logic → Fallback chain → Full test coverage ↗
                                                                         ↓
User accounts → Real sending → All jurisdictions → Analytics → Multi-bill → v3
```
