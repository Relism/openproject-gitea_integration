# frozen_string_literal: true

module OpenProject
  module GiteaIntegration
    require "open_project/gitea_integration/engine"

    def self.settings
      Hash(Setting.plugin_openproject_gitea_integration).with_indifferent_access
    end
  end
end
