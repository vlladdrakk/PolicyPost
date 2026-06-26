class BillsController < ApplicationController
  def index
    @bills = Bill.approved

    if params[:category].present? && DomainConstants::CATEGORIES.include?(params[:category])
      @bills = @bills.where(category: params[:category])
    end
    if params[:status].present? && DomainConstants::STATUSES.include?(params[:status])
      @bills = @bills.where(status: params[:status])
    end
    if params[:q].present?
      q = "%#{Bill.sanitize_sql_like(params[:q])}%"
      @bills = @bills.where(
        "bill_number LIKE :q OR title LIKE :q OR short_title LIKE :q", q: q
      )
    end
    if params[:exclude_senate] == "1"
      @bills = @bills.where.not(originating_chamber: "Senate")
    end

    @bills = @bills.order(updated_at: :desc).page(params[:page]).per(25)
    @exclude_senate = params[:exclude_senate] == "1"
    @filter_params = params.permit(:category, :status, :q, :exclude_senate).to_h.compact_blank
  end

  def show
    @bill = Bill.approved.find(params[:id])
    @ministers = ministers_for_selection(@bill)
    @prime_minister = Representative.find_by(title: "Prime Minister")
  end

  helper_method :ministry_matches_bill?

  private

  def ministers_for_selection(bill)
    ministers = Representative.where(is_minister: true).order(:name).to_a
    suggested_index = ministers.index { |m| ministry_matches_bill?(m.ministry_name, bill.category) }

    if suggested_index
      suggested = ministers.delete_at(suggested_index)
      [ suggested ] + ministers
    else
      ministers
    end
  end

  def ministry_matches_bill?(ministry_name, category)
    return false if ministry_name.blank?

    ministry = ministry_name.downcase
    cat = category.to_s.downcase
    ministry.include?(cat) || cat.include?(ministry)
  end
end
