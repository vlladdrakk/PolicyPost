module Admin
  class BillQuestionSelectionsController < ApplicationController
    before_action :set_bill

    def create
      question_id = params[:question_id]
      position = params[:position].to_s.strip
      question = Question.active.find(question_id)

      @bill.bill_question_selections.create!(
        question: question,
        position: position
      )
      PolicyPost::DataPipeline::PhraseMatching.reassign(@bill)
      redirect_to admin_bill_path(@bill), notice: "Question added to #{position}."
    end

    def destroy
      selection = @bill.bill_question_selections.find(params[:id])
      selection.destroy!
      PolicyPost::DataPipeline::PhraseMatching.reassign(@bill)
      redirect_to admin_bill_path(@bill), notice: "Question removed."
    end

    private

    def set_bill
      @bill = Bill.find(params[:bill_id])
    end
  end
end
