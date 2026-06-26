module Admin
  class BillsController < ApplicationController
    before_action :set_bill, only: [ :show, :update, :reprocess ]

    def index
      @status = params[:status] || "review"
      @bills = if @status == "all"
        Bill.order(updated_at: :desc)
      else
        Bill.where(processing_status: @status).order(updated_at: :desc)
      end

      @exclude_senate = params[:exclude_senate] == "1"
      @bills = @bills.where.not(originating_chamber: "Senate") if @exclude_senate

      base = Bill.all
      counts = Bill.group(:processing_status).count
      @stats = {
        total: base.count,
        pending: counts["pending"] || 0,
        processing: counts["processing"] || 0,
        review: counts["review"] || 0,
        approved: counts["approved"] || 0
      }
    end

    def show
      load_review_data
    end

    def update
      case params[:commit]
      when "Approve Bill"
        if pending_generated_questions?
          flash.now[:alert] = "All generated questions must be approved or rejected before this bill can be approved."
          load_review_data
          render :show, status: :unprocessable_entity
          return
        end

        @bill.approve!
        redirect_to admin_bills_path, notice: "Bill #{@bill.bill_number} approved."
      when "Reject Bill"
        reason = params[:bill]&.dig(:review_notes).to_s.strip
        if reason.blank?
          flash.now[:alert] = "A rejection reason is required."
          load_review_data
          render :show, status: :unprocessable_entity
          return
        end
        @bill.reject!(reason: reason)
        redirect_to admin_bills_path, notice: "Bill #{@bill.bill_number} rejected."
      when "Update Category"
        new_category = params[:bill]&.dig(:category)
        if new_category.present? && DomainConstants::CATEGORIES.include?(new_category)
          @bill.update!(category: new_category)
          redirect_to admin_bill_path(@bill), notice: "Category updated."
        else
          redirect_to admin_bill_path(@bill), alert: "Invalid category."
        end
      else
        redirect_to admin_bill_path(@bill)
      end
    rescue ArgumentError => e
      flash.now[:alert] = e.message
      load_review_data
      render :show, status: :unprocessable_entity
    end

    def reprocess
      @bill.update!(processing_status: "pending", review_notes: nil)
      BillProcessingJob.perform_later(@bill.id)
      redirect_to admin_bills_path(status: "all"), notice: "#{@bill.bill_number} queued for reprocessing."
    end

    def reset_all
      count = 0
      Bill.find_each do |bill|
        bill.update!(processing_status: "pending", review_notes: nil)
        BillProcessingJob.perform_later(bill.id)
        count += 1
      end
      redirect_to admin_bills_path(status: "all"), notice: "#{count} bill(s) queued for reprocessing."
    end

    private

    def set_bill
      @bill = Bill.find(params[:id])
    end

    def load_review_data
      @support_selections = @bill.bill_question_selections
        .includes(:question, :question_phrases)
        .where(position: "support")
        .order("questions.question_type")
      @oppose_selections = @bill.bill_question_selections
        .includes(:question, :question_phrases)
        .where(position: "oppose")
        .order("questions.question_type")
      @verified_phrases = @bill.bill_phrases.verified.order(:phrase)
      @fallback_warning = @bill.review_notes&.include?("defaulted to governance")
      @generated_questions = {
        "support" => generated_questions_for("support"),
        "oppose" => generated_questions_for("oppose")
      }
      @remaining_questions = {
        "support" => remaining_questions_for("support"),
        "oppose" => remaining_questions_for("oppose")
      }
    end

    def generated_questions_for(position)
      @bill.generated_questions.generated.where(position: position).order(:status, :created_at)
    end

    def pending_generated_questions?
      @bill.generated_questions.generated.pending.exists?
    end

    def remaining_questions_for(position)
      selected_ids = @bill.bill_question_selections.where(position: position).pluck(:question_id)
      Question.templates.active
        .where(category: @bill.category, position: position)
        .where.not(id: selected_ids)
        .order(:question_type)
    end
  end
end
