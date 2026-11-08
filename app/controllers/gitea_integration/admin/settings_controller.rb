# frozen_string_literal: true

module GiteaIntegration
  module Admin
    class SettingsController < ApplicationController
      layout "admin"
      menu_item :admin_gitea_integration
      before_action :require_admin

      def show
        @settings = OpenProject::GiteaIntegration.settings
        @actor = User.find_by(id: @settings[:gitea_user_id]) if @settings[:gitea_user_id].present?
      end

      def update
        Setting.plugin_openproject_gitea_integration =
          OpenProject::GiteaIntegration.settings.merge(params.permit(:gitea_user_id, :webhook_secret).to_h)
        flash[:notice] = I18n.t(:notice_successful_update)
        redirect_to gitea_integration_admin_settings_path
      end
    end
  end
end
