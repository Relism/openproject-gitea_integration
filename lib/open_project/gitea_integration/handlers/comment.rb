# frozen_string_literal: true

module OpenProject::GiteaIntegration
  module Handlers
    # A new comment on an issue or pull request links it to the work packages the comment references.
    class Comment < Base
      def call
        linked = linked_by_comment or return

        comment!(linked.work_packages, linked.references, note_key, target: target_link, quote: quote(body))
      end

      private

      def linked_by_comment
        return unless payload["action"] == "created"

        linked = link!(model, target, text: [body])
        linked if linked&.work_packages.present?
      end

      def body = payload.fetch("comment")["body"]

      def pull_request? = payload["is_pull"] && payload["pull_request"].present?

      def model = pull_request? ? GiteaPullRequest : GiteaIssue

      def target = pull_request? ? payload["pull_request"] : payload.fetch("issue")

      def note_key = pull_request? ? :pull_request_commented : :issue_commented

      def target_link = link("##{target['number']} #{target['title']}", payload.dig("comment", "html_url"))
    end
  end
end
