# frozen_string_literal: true

module OpenProject::GiteaIntegration
  module Handlers
    # Gitea reports reviews as their own events: pull_request_approved, pull_request_rejected
    # and pull_request_comment (a review that only comments).
    class PullRequestReview < Base
      KEYS = {
        "pull_request_review_approved" => :pull_request_approved,
        "pull_request_review_rejected" => :pull_request_changes_requested,
        "pull_request_review_comment" => :pull_request_reviewed
      }.freeze
      REVIEW_STATES = { pull_request_approved: "approved", pull_request_changes_requested: "changes_requested" }.freeze

      def call
        key = review_key or return
        linked = link!(GiteaPullRequest, pull_request) or return

        record_review!(linked.record, REVIEW_STATES[key])
        comment!(linked.work_packages, linked.references, key, pull_request: item_link(pull_request), quote: review_quote)
      end

      private

      def pull_request = payload.fetch("pull_request")

      def review_key = KEYS[event_type] || KEYS[payload.dig("review", "type")]

      def review_quote = quote(payload.dig("review", "content"))

      def record_review!(pull_request, review_state)
        pull_request.update!(review_state:, reviewed_by: GiteaUser.upsert_from_payload(sender)) if review_state
      end
    end
  end
end
