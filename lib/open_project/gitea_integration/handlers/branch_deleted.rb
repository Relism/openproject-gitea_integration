# frozen_string_literal: true

module OpenProject::GiteaIntegration
  module Handlers
    class BranchDeleted < Base
      def call
        untrack_branch!(payload["ref"]) if payload["ref_type"] == "branch"
      end
    end
  end
end
