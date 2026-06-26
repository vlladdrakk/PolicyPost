class SessionsController < ApplicationController
  before_action :set_user_session, only: [
    :edit_bill, :update_bill,
    :edit_position, :update_position,
    :show_questions, :answer_questions,
    :show_draft, :draft_data, :draft_status,
    :answer_status,
    :update_draft
  ]

  RECIPIENT_TYPES = ConstituentLetter::RECIPIENT_TYPES

  def create
    bill = Bill.approved.find(params[:bill_id])
    recipient_type = params[:recipient_type]

    unless RECIPIENT_TYPES.include?(recipient_type)
      redirect_to bill_path(bill), alert: "Please select a recipient."
      return
    end

    case recipient_type
    when "local_mp"
      create_local_mp_session(bill)
    when "prime_minister"
      create_prime_minister_session(bill)
    when "cabinet_minister"
      create_cabinet_minister_session(bill)
    end
  end

  def edit_bill
    @rep_info = rep_info_for(@user_session)
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

    @bills = @bills.order(updated_at: :desc).page(params[:page]).per(25)

    @filter_params = params.permit(:category, :status, :q).to_h.compact_blank
  end

  def update_bill
    bill = Bill.approved.find(params[:bill_id])
    letter = @user_session.constituent_letter
    letter.update!(bill: bill)
    redirect_to edit_position_session_path(@user_session)
  end

  def edit_position
    @bill = @user_session.constituent_letter.bill
  end

  def update_position
    letter = @user_session.constituent_letter
    position = params[:position]

    unless DomainConstants::POSITIONS.include?(position)
      flash.now[:alert] = "Please select a position."
      @bill = letter.bill
      render :edit_position, status: :unprocessable_entity
      return
    end

    letter.update!(position: position)
    redirect_to questions_session_path(@user_session)
  end

  def show_questions
    redirect_to edit_position_session_path(@user_session) and return unless @user_session.constituent_letter

    @letter = @user_session.constituent_letter
    @selections = @letter.bill.bill_question_selections
      .includes(:question, :question_phrases)
      .where(position: @letter.position)
      .order("questions.question_type")

    @follow_up = params[:follow_up]
    @follow_up_text = params[:follow_up_text]
    @processing = params[:processing].present?

    if @processing
      # Answers are being checked async — view renders polling spinner
    elsif @follow_up
      setup_follow_up_display
    else
      setup_normal_questions
    end
  end

  def answer_questions
    redirect_to edit_position_session_path(@user_session) and return unless @user_session.constituent_letter

    @letter = @user_session.constituent_letter

    if params[:follow_up_question_id].present?
      save_follow_up
      return redirect_to draft_session_path(@user_session)
    end

    answers = params[:answers] || {}

    answers.each do |question_id, answer_text|
      next if answer_text.blank?

      selection = @letter.bill.bill_question_selections.find_by(question_id: question_id)
      next unless selection

      intake = @letter.intake_answers.find_or_initialize_by(question_id: question_id)
      intake.answer = answer_text
      intake.verdict = nil
      intake.save!
    end

    redirect_to questions_session_path(@user_session, processing: true)
  end

  def show_draft
    redirect_to edit_position_session_path(@user_session) and return unless @user_session.constituent_letter

    @letter = @user_session.constituent_letter
  end

  def draft_data
    redirect_to edit_position_session_path(@user_session) and return unless @user_session.constituent_letter

    @letter = @user_session.constituent_letter
    @draft = @letter.email_drafts.order(created_at: :desc).first

    if @draft&.status == "complete"
      return render json: {
        body: @draft.body,
        quality_status: @draft.quality_status,
        warnings: @draft.quality_warnings&.split("; ") || []
      }
    end

    unless @draft&.status == "processing"
      @draft ||= @letter.email_drafts.build(approach: "A", body: "")
      @draft.processing!
      DraftGenerationJob.perform_later(@draft.id)
    end

    render json: { status: "processing" }
  end

  def draft_status
    redirect_to edit_position_session_path(@user_session) and return unless @user_session.constituent_letter

    letter = @user_session.constituent_letter
    draft = letter.email_drafts.order(created_at: :desc).first

    if draft.nil?
      render json: { status: "none" }
    elsif draft.status == "complete"
      render json: {
        status: "complete",
        body: draft.body,
        quality_status: draft.quality_status,
        warnings: draft.quality_warnings&.split("; ") || []
      }
    elsif draft.status == "processing"
      render json: { status: "processing" }
    else
      render json: { status: draft.status || "pending" }
    end
  end

  def answer_status
    redirect_to edit_position_session_path(@user_session) and return unless @user_session.constituent_letter

    letter = @user_session.constituent_letter
    unchecked = letter.intake_answers.where(verdict: nil).includes(:question)

    vague_question = nil
    vague_follow_up = nil
    all_good = true

    unchecked.each do |intake|
      question = intake.question
      adapted = question.body.gsub("{bill_subject}", letter.bill.short_title.presence || letter.bill.bill_number)

      result = PolicyPost::UserPipeline::AnswerRelevance.check(
        question: adapted, answer: intake.answer
      )
      intake.update!(
        verdict: result[:verdict],
        follow_up_text: result[:follow_up]
      )

      if result[:verdict] == "vague"
        all_good = false
        vague_question ||= intake.question_id
        vague_follow_up ||= result[:follow_up]
      end
    end

    if unchecked.empty?
      letter.intake_answers.order(:id).each do |intake|
        if intake.verdict == "vague"
          all_good = false
          vague_question ||= intake.question_id
          vague_follow_up ||= intake.follow_up_text
          break
        end
      end
    end

    if all_good
      render json: { status: "complete", all_good: true }
    else
      render json: {
        status: "complete",
        all_good: false,
        vague: {
          question_id: vague_question.to_s,
          follow_up_text: vague_follow_up || PolicyPost::UserPipeline::AnswerRelevance::FOLLOW_UPS[0]
        }
      }
    end
  rescue => e
    Rails.logger.error "[answer_status] Error: #{e.message}"
    render json: { status: "failed", error: e.message }, status: :internal_server_error
  end

  def update_draft
    redirect_to edit_position_session_path(@user_session) and return unless @user_session.constituent_letter

    @letter = @user_session.constituent_letter
    @draft = @letter.email_drafts.last

    body = params[:body] || @draft&.body || ""
    @draft&.update!(body: body)

    flash[:notice] = "Your draft has been saved."
    redirect_to draft_session_path(@user_session)
  end

  private

  def set_user_session
    @user_session = UserSession.find(params[:id])
  end

  def create_local_mp_session(bill)
    code = params[:postal_code].to_s.upcase.strip

    if code.blank?
      redirect_to bill_path(bill), alert: "Please enter a postal code."
      return
    end

    postal = PostalCode.find_by(code: code)
    postal ||= PolicyPost::RepresentativeImporter.lookup_postal_code(code)

    unless postal
      redirect_to bill_path(bill), alert: "Postal code #{code} not found. Try K1P1A4."
      return
    end

    riding = postal.riding
    rep = riding.representatives.first

    unless rep
      redirect_to bill_path(bill), alert: "No representative found for #{riding.name}."
      return
    end

    create_session_and_letter(
      bill: bill,
      representative: rep,
      riding: riding,
      recipient_type: "local_mp",
      postal_code: code
    )
  end

  def create_prime_minister_session(bill)
    rep = Representative.find_by(title: "Prime Minister")

    unless rep
      redirect_to bill_path(bill), alert: "Prime Minister representative is not configured."
      return
    end

    create_session_and_letter(
      bill: bill,
      representative: rep,
      riding: nil,
      recipient_type: "prime_minister",
      postal_code: nil
    )
  end

  def create_cabinet_minister_session(bill)
    minister_id = params[:minister_id]

    if minister_id.blank?
      redirect_to bill_path(bill), alert: "Please select a cabinet minister."
      return
    end

    rep = Representative.find_by(id: minister_id, is_minister: true)

    unless rep
      redirect_to bill_path(bill), alert: "Selected minister not found."
      return
    end

    create_session_and_letter(
      bill: bill,
      representative: rep,
      riding: nil,
      recipient_type: "cabinet_minister",
      postal_code: nil
    )
  end

  def create_session_and_letter(bill:, representative:, riding:, recipient_type:, postal_code:)
    letter = ConstituentLetter.create!(
      riding: riding,
      representative: representative,
      bill: bill,
      postal_code: postal_code,
      position: DomainConstants::POSITIONS.first,
      recipient_type: recipient_type,
      drafting_approach: "A"
    )

    session = UserSession.create!(
      postal_code: postal_code,
      riding: riding&.name,
      constituent_letter: letter
    )

    redirect_to edit_position_session_path(session)
  end

  def follow_up_for?(selection)
    letter = @user_session.constituent_letter
    return false unless letter

    intake = letter.intake_answers.find_by(question_id: selection.question_id)
    intake&.verdict == "vague" && intake.follow_up_answer.blank?
  end

  def setup_normal_questions
    @adapted_questions = @selections.map do |sel|
      question_with_phrases = PolicyPost::PhraseVerification::QuestionWithPhrases.new(
        id: sel.id,
        phrases: sel.question_phrases.ranked.map { |qp|
          PolicyPost::PhraseVerification::RankedPhrase.new(text: qp.bill_phrase.phrase, rank: qp.rank)
        }
      )

      fallback = @letter.bill.short_title.presence || @letter.bill.bill_number
      selected_phrase = PolicyPost::PhraseVerification.select_phrases(
        [ question_with_phrases ], strategy: "top_only", fallback: fallback
      )[sel.id]

      {
        selection: sel,
        question_body: sel.question.body.gsub("{bill_subject}", selected_phrase || fallback)
      }
    end
  end

  def setup_follow_up_display
    @saved_answers = @letter.intake_answers.includes(:question).order(:id).map do |ia|
      selection = @selections.find { |s| s.question_id == ia.question_id }
      question_body = selection&.question&.body&.gsub("{bill_subject}", @letter.bill.short_title.presence || @letter.bill.bill_number) || ia.question.body

      {
        question_body: question_body,
        answer: ia.answer
      }
    end

    follow_up_selection = @selections.find { |s| s.question_id.to_s == @follow_up.to_s }
    @follow_up_question_body = follow_up_selection&.question&.body&.gsub("{bill_subject}", @letter.bill.short_title.presence || @letter.bill.bill_number) || ""
  end

  def save_follow_up
    intake = @letter.intake_answers.find_by(question_id: params[:follow_up_question_id])
    return unless intake
    intake.update!(follow_up_answer: params[:follow_up_answer])
  end
end
