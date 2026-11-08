# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :gitea_integration do
    namespace :admin do
      resource :settings, only: %i[show update]
    end
  end

  resources :projects, only: [] do
    resources :work_packages, only: [] do
      resource :gitea, controller: "gitea_integration/work_package_tab", only: [] do
        get :tab
        get :refresh
        get :count
        get :git_snippets_dialog
      end
    end
  end
end
