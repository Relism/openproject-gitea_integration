# frozen_string_literal: true

module OpenProject::GiteaIntegration
  module Handlers
    # State changes notify the work packages referenced in the title or description;
    # any other update only notifies work packages referenced for the first time.
    class PullRequest < Base
      def call
        linked = link!(GiteaPullRequest, pull_request) or return
        key = state_change_key

        comment!(key ? linked.work_packages : linked.newly_linked, linked.references, key || :pull_request_referenced,
                 pull_request: item_link(pull_request))
      end

      private

      def pull_request = payload.fetch("pull_request")

      def state_change_key
        case payload["action"]
        when "opened" then pull_request["draft"] ? :pull_request_opened_draft : :pull_request_opened
        when "reopened" then :pull_request_reopened
        when "closed" then pull_request["merged"] ? :pull_request_merged : :pull_request_closed
        end
      end
    end
  end
end
