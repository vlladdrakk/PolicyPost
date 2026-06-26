# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_25_160432) do
  create_table "bill_phrases", force: :cascade do |t|
    t.integer "bill_id", null: false
    t.datetime "created_at", null: false
    t.string "phrase", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified", default: true, null: false
    t.index ["bill_id"], name: "index_bill_phrases_on_bill_id"
  end

  create_table "bill_question_selections", force: :cascade do |t|
    t.integer "bill_id", null: false
    t.datetime "created_at", null: false
    t.string "position", null: false
    t.integer "question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["bill_id", "position", "question_id"], name: "idx_on_bill_id_position_question_id_62f5431f4c", unique: true
    t.index ["bill_id"], name: "index_bill_question_selections_on_bill_id"
    t.index ["question_id"], name: "index_bill_question_selections_on_question_id"
  end

  create_table "bills", force: :cascade do |t|
    t.string "bill_number", null: false
    t.string "bill_type"
    t.string "category", default: "governance", null: false
    t.datetime "created_at", null: false
    t.text "full_text"
    t.string "full_text_url"
    t.date "introduced_date"
    t.boolean "is_government_bill", default: false, null: false
    t.string "jurisdiction", null: false
    t.date "last_updated_date"
    t.string "legislature_session", null: false
    t.string "originating_chamber"
    t.integer "parliament_number"
    t.string "processing_status", default: "pending", null: false
    t.text "review_notes"
    t.integer "session_number"
    t.string "short_title"
    t.integer "source_bill_id", null: false
    t.string "source_id", null: false
    t.string "source_url", null: false
    t.string "sponsor_name"
    t.string "sponsor_party"
    t.string "sponsor_riding"
    t.string "status", null: false
    t.text "summary"
    t.text "title", null: false
    t.datetime "updated_at", null: false
    t.index ["bill_number"], name: "index_bills_on_bill_number"
    t.index ["jurisdiction", "source_id"], name: "index_bills_on_jurisdiction_and_source_id", unique: true
    t.index ["source_bill_id"], name: "index_bills_on_source_bill_id", unique: true
  end

  create_table "constituent_letters", force: :cascade do |t|
    t.integer "bill_id", null: false
    t.datetime "created_at", null: false
    t.string "drafting_approach", default: "A", null: false
    t.string "position", null: false
    t.string "postal_code"
    t.string "recipient_type", default: "local_mp", null: false
    t.integer "representative_id", null: false
    t.integer "riding_id"
    t.datetime "updated_at", null: false
    t.index ["bill_id"], name: "index_constituent_letters_on_bill_id"
    t.index ["representative_id"], name: "index_constituent_letters_on_representative_id"
    t.index ["riding_id"], name: "index_constituent_letters_on_riding_id"
  end

  create_table "email_drafts", force: :cascade do |t|
    t.string "approach", null: false
    t.text "body", null: false
    t.integer "constituent_letter_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_attempted_at"
    t.string "quality_status"
    t.text "quality_warnings"
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.index ["constituent_letter_id"], name: "index_email_drafts_on_constituent_letter_id"
    t.index ["status"], name: "index_email_drafts_on_status"
  end

  create_table "intake_answers", force: :cascade do |t|
    t.text "answer", null: false
    t.integer "constituent_letter_id", null: false
    t.datetime "created_at", null: false
    t.text "follow_up_answer"
    t.string "follow_up_text"
    t.integer "question_id", null: false
    t.datetime "updated_at", null: false
    t.string "verdict"
    t.index ["constituent_letter_id"], name: "index_intake_answers_on_constituent_letter_id"
    t.index ["question_id"], name: "index_intake_answers_on_question_id"
  end

  create_table "postal_codes", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "riding_id", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_postal_codes_on_code", unique: true
    t.index ["riding_id"], name: "index_postal_codes_on_riding_id"
  end

  create_table "question_phrases", force: :cascade do |t|
    t.integer "bill_phrase_id", null: false
    t.integer "bill_question_selection_id", null: false
    t.datetime "created_at", null: false
    t.integer "rank", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["bill_phrase_id"], name: "index_question_phrases_on_bill_phrase_id"
    t.index ["bill_question_selection_id", "rank"], name: "index_question_phrases_on_bill_question_selection_id_and_rank"
    t.index ["bill_question_selection_id"], name: "index_question_phrases_on_bill_question_selection_id"
  end

  create_table "questions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "bill_id"
    t.text "body", null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "position", null: false
    t.integer "priority", default: 0, null: false
    t.string "question_type", null: false
    t.string "source", default: "template", null: false
    t.string "status", default: "approved", null: false
    t.datetime "updated_at", null: false
    t.index ["bill_id", "position", "status"], name: "index_questions_on_bill_id_and_position_and_status"
    t.index ["bill_id"], name: "index_questions_on_bill_id"
    t.index ["source", "status"], name: "index_questions_on_source_and_status"
  end

  create_table "representatives", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.boolean "is_minister", default: false, null: false
    t.string "ministry_name"
    t.string "name"
    t.integer "riding_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["riding_id"], name: "index_representatives_on_riding_id"
  end

  create_table "ridings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "federal_riding_code"
    t.string "name", null: false
    t.string "province", null: false
    t.datetime "updated_at", null: false
    t.index ["province", "name"], name: "index_ridings_on_province_and_name", unique: true
    t.index ["province"], name: "index_ridings_on_province"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "user_sessions", force: :cascade do |t|
    t.integer "constituent_letter_id"
    t.datetime "created_at", null: false
    t.string "postal_code"
    t.string "riding"
    t.datetime "updated_at", null: false
    t.index ["constituent_letter_id"], name: "index_user_sessions_on_constituent_letter_id"
  end

  add_foreign_key "bill_phrases", "bills"
  add_foreign_key "bill_question_selections", "bills"
  add_foreign_key "bill_question_selections", "questions"
  add_foreign_key "constituent_letters", "bills"
  add_foreign_key "constituent_letters", "representatives"
  add_foreign_key "constituent_letters", "ridings"
  add_foreign_key "email_drafts", "constituent_letters"
  add_foreign_key "intake_answers", "constituent_letters"
  add_foreign_key "intake_answers", "questions"
  add_foreign_key "postal_codes", "ridings"
  add_foreign_key "question_phrases", "bill_phrases"
  add_foreign_key "question_phrases", "bill_question_selections"
  add_foreign_key "questions", "bills"
  add_foreign_key "representatives", "ridings"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "user_sessions", "constituent_letters"
end
