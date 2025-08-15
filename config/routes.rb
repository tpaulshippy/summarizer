Rails.application.routes.draw do
  get "municipalities/index"
  get "municipalities/show"
  get "meetings/index"
  get "meetings/show"
  get "up" => "rails/health#show", as: :rails_health_check

  root to: "meetings#index"

  resources :municipalities, only: [ :index, :show ]
  resources :meetings, only: [ :index, :show ]

  # Solid Queue Dashboard
  mount SolidQueueDashboard::Engine, at: "/solid_queue"
end
