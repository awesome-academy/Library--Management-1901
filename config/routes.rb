Rails.application.routes.draw do
  post "/rate", to: "rater#create", as: "rate"
  devise_for :users, controllers: {omniauth_callbacks: "users/omniauth_callbacks"}
  scope "(:locale)", locale: /en|vi/ do
    root to: "static_pages#home"
    get "/help", to: "static_pages#help"
    get "/about", to: "static_pages#about"
    get "/contact", to: "static_pages#contact"

    devise_scope :user do
      resources :users do
        resources :borrows
        member do
          get :following, :followers
        end
      end
    end

    resources :follow_books, only: [:create, :destroy]
    resources :relationships, only: [:create, :destroy]
    resources :like_books, only: [:create, :destroy]

    resources :books, only: %i(index show) do
      resources :comments, only: [:create, :destroy]
    end
    namespace :admin do
      resources :users
      resources :books
      resources :borrows
      resources :categories
      resources :statistics, only: [:index]
    end
  end
end
