# frozen_string_literal: true

module OpenProject::GiteaIntegration
  module Handlers
    class BranchCreated < Base
      def call
        track_branch!(payload["ref"], head_sha: payload["sha"]) if payload["ref_type"] == "branch"
      end
    end
  end
end
