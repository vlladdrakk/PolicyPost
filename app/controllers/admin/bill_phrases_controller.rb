module Admin
  class BillPhrasesController < ApplicationController
    before_action :set_bill

    def create
      phrase = params[:phrase].to_s.strip
      if phrase.present?
        @bill.bill_phrases.create!(phrase: phrase, verified: true)
        PolicyPost::DataPipeline::PhraseMatching.reassign(@bill)
        redirect_to admin_bill_path(@bill), notice: "Phrase added."
      else
        redirect_to admin_bill_path(@bill), alert: "Phrase cannot be blank."
      end
    end

    def destroy
      phrase = @bill.bill_phrases.find(params[:id])
      phrase.destroy!
      PolicyPost::DataPipeline::PhraseMatching.reassign(@bill)
      redirect_to admin_bill_path(@bill), notice: "Phrase removed."
    end

    private

    def set_bill
      @bill = Bill.find(params[:bill_id])
    end
  end
end
