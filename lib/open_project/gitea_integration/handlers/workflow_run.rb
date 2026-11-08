# frozen_string_literal: true

module OpenProject::GiteaIntegration
  module Handlers
    class WorkflowRun < Base
      def call = GiteaWorkflowRun.upsert_from_payload(payload)
    end
  end
end
