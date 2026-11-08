# frozen_string_literal: true

module OpenProject::GiteaIntegration
  module Handlers
    class Issue < Base
      STATE_CHANGES = { "opened" => :issue_opened, "closed" => :issue_closed, "reopened" => :issue_reopened }.freeze

      def call
        linked = link!(GiteaIssue, issue) or return
        key = STATE_CHANGES[payload["action"]]

        comment!(key ? linked.work_packages : linked.newly_linked, linked.references, key || :issue_referenced,
                 issue: item_link(issue))
      end

      private

      def issue = payload.fetch("issue")
    end
  end
end
