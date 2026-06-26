# PolicyPost

A civic letter generator that helps Canadian constituents draft formal emails to their elected representatives about bills.

**Flow:** postal code → representatives → bill → position → intake questions → SLM-drafted email → edit/send.

## Tech stack

- **Rails 8.1**, Ruby 3.2, SQLite
- **importmap**, Turbo, Stimulus
- **Solid Queue** (background jobs), **Solid Cache**, **Solid Cable**
- **Minitest** (unit + system), Capybara/Selenium
- **Kamal** for deployment

## Architecture

Two execution contexts that must not be conflated:

- **Data pipeline** (batch, at bill ingestion): pre-computes classification, key-phrase extraction, bill-specific question generation, question selection, and phrase–question matching. Results are reviewed before a bill goes live.
- **User pipeline** (real-time, per session): answer-relevance checks, email drafting, quality checks. Reads pre-computed data-pipeline outputs.

Full specification in `spec.md`. Agent workflow documentation in `AGENTS.md`.

## Setup

```bash
bundle install
bin/rails db:prepare
bin/rails db:seed            # loads question bank + sample representatives
```

Start Solid Queue for background jobs (bill processing, email drafting):

```bash
bundle exec solid_queue start
```

Start the server:

```bash
bin/rails server
```

## Development commands

| Command | What it does |
|---|---|
| `bin/rails db:test:prepare test` | Run all tests |
| `bin/rails db:test:prepare test:system` | Run system tests only |
| `bin/rails test test/models/bill_test.rb:42` | Run a single test |
| `bin/rubocop -f github` | Lint Ruby |
| `bin/brakeman --no-pager` | Security scan |
| `bin/bundler-audit` | Dependency audit |
| `bin/importmap audit` | Importmap audit |
| `bin/rails db:migrate` | Run migrations |
| `bin/rails console` | Rails console |

CI runs `scan_ruby`, `scan_js`, `lint`, `test`, and `system-test` as separate jobs.

## Feature summary

- **Ingestion**: scrapes bills from LEGISinfo (federal); adapter pattern for future provincial sources
- **SLM pipeline**: 6 tasks — classification, phrase extraction, question generation, question selection, phrase matching, email drafting
- **Review**: human-in-the-loop approval gate before bills go live
- **Drafting**: two approaches — single-pass scaffold (A) and incremental (B, planned)
- **Quality**: 6 independent checks (4 LLM + 2 programmatic) with configurable aggregation
- **Tests**: 163 tests, 0 failures, 0 errors across 25 test files
