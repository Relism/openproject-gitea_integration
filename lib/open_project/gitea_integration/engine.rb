# frozen_string_literal: true

require "open_project/plugins"

module OpenProject::GiteaIntegration
  class Engine < ::Rails::Engine
    engine_name :openproject_gitea_integration

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-gitea_integration",
             settings: { default: { "gitea_user_id" => nil, "webhook_secret" => nil } } do
      ::Redmine::MenuManager.map(:admin_menu) do |menu|
        menu.push :admin_gitea_integration,
                  { controller: "/gitea_integration/admin/settings", action: "show" },
                  parent: :admin_integrations,
                  if: ->(_) { User.current.admin? },
                  caption: "Gitea",
                  icon: :"git-branch"
      end

      project_module(:gitea, dependencies: :work_package_tracking) do
        permission(:show_gitea_content, {}, permissible_on: %i[work_package project])
      end

      menu :work_package_split_view,
           :gitea,
           { tab: :gitea },
           if: ->(project) { User.current.allowed_in_project?(:show_gitea_content, project) },
           skip_permissions_check: true,
           badge: ->(work_package:, **) { ::GiteaIntegration::LinkedItems.new(work_package).count },
           before: :watchers,
           caption: :project_module_gitea
    end

    patches %w[WorkPackage]

    initializer "gitea.register_hook" do
      ::OpenProject::Webhooks.register_hook("gitea") do |_hook, request, params, user|
        HookHandler.new.process(request, params, user)
      end
    end

    initializer "gitea.status_colors" do
      Rails.application.reloader.to_prepare do
        ::GiteaIntegration::Status::GROUPS.each do |key, statuses|
          ::Highlighting::Registry.register_static(key: "gitea_#{key}_status", values: statuses.values)
        end
      end
    end

    extend_api_response(:v3, :work_packages, :work_package) do
      link :gitea, cache_if: -> { current_user.allowed_in_work_package?(:show_gitea_content, represented) } do
        next if represented.new_record?

        { href: "#{work_package_path(id: represented.id)}/tabs/gitea", title: "Gitea" }
      end
    end

    add_cron_jobs do
      { "GiteaIntegration::CleanupJob": { cron: "35 1 * * *", class: "GiteaIntegration::CleanupJob" } }
    end
  end
end
