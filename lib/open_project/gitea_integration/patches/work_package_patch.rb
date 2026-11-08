# frozen_string_literal: true

module OpenProject::GiteaIntegration
  module Patches
    module WorkPackagePatch
      extend ActiveSupport::Concern

      included do
        has_and_belongs_to_many :gitea_pull_requests
        has_and_belongs_to_many :gitea_issues
        has_and_belongs_to_many :gitea_commits
        has_many :gitea_branches, dependent: :destroy
      end
    end
  end
end
