Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "bills#index"

  get "/bill/:id", to: "bills#show", as: :bill
  post "/session", to: "sessions#create", as: :sessions

  get "/session/:id/bill", to: "sessions#edit_bill", as: :edit_bill_session
  patch "/session/:id/bill", to: "sessions#update_bill", as: :update_bill_session
  get "/session/:id/position", to: "sessions#edit_position", as: :edit_position_session
  patch "/session/:id/position", to: "sessions#update_position", as: :update_position_session
  get "/session/:id/questions", to: "sessions#show_questions", as: :questions_session
  patch "/session/:id/questions", to: "sessions#answer_questions", as: :answer_questions_session
  get "/session/:id/draft", to: "sessions#show_draft", as: :draft_session
  get "/session/:id/draft_data", to: "sessions#draft_data", as: :draft_data_session
  get "/session/:id/draft_status", to: "sessions#draft_status", as: :draft_status_session
  get "/session/:id/answer_status", to: "sessions#answer_status", as: :answer_status_session
  patch "/session/:id/draft", to: "sessions#update_draft", as: :update_draft_session

  namespace :admin do
    resources :bills, only: [ :index, :show, :update ] do
      collection do
        post :reset_all
      end
      member do
        post :reprocess
      end
      resources :phrases, only: [ :create, :destroy ], controller: "bill_phrases"
      resources :selections, only: [ :create, :destroy ], controller: "bill_question_selections"
      resources :generated_questions, only: [ :update ] do
        member do
          patch :approve
          patch :reject
        end
      end
    end
  end

  mount MissionControl::Jobs::Engine, at: "/jobs"
end
