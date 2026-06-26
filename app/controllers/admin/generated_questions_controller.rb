module Admin
  class GeneratedQuestionsController < ApplicationController
    before_action :set_bill
    before_action :set_question

    def update
      body = params[:question]&.dig(:body).to_s.strip
      if body.blank?
        redirect_to admin_bill_path(@bill), alert: "Question body cannot be blank."
        return
      end

      @question.update!(body: body, status: "approved")
      rebuild_selections
      redirect_to admin_bill_path(@bill), notice: "Generated question updated and approved."
    end

    def approve
      @question.update!(status: "approved")
      rebuild_selections
      redirect_to admin_bill_path(@bill), notice: "Generated question approved."
    end

    def reject
      @question.update!(status: "rejected")
      rebuild_selections
      redirect_to admin_bill_path(@bill), notice: "Generated question rejected."
    end

    private

    def set_bill
      @bill = Bill.find(params[:bill_id])
    end

    def set_question
      @question = @bill.generated_questions.find(params[:id])
    end

    def rebuild_selections
      selections = PolicyPost::DataPipeline::QuestionSelection.call(@bill, position: @question.position)
      PolicyPost::DataPipeline::PhraseMatching.reassign(@bill) if selections.any?
    rescue PolicyPost::SlmUnavailableError => e
      Rails.logger.warn "[GeneratedQuestions] SLM unreachable during rebuild: #{e.message}"
      selections = PolicyPost::DataPipeline::QuestionSelection.rule_based_fallback(
        PolicyPost::DataPipeline::QuestionSelection.build_candidates(@bill, @question.position)
      )
      PolicyPost::DataPipeline::QuestionSelection.create_selections(@bill, selections, @question.position)
      PolicyPost::DataPipeline::PhraseMatching.reassign(@bill) if selections.any?
    end
  end
end
