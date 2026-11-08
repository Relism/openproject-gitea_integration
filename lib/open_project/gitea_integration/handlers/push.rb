# frozen_string_literal: true

module OpenProject::GiteaIntegration
  module Handlers
    # Links commits that reference work packages and keeps branches in sync. Branch creation and
    # deletion are also derived from the zero SHA, so tracking works with only "push" subscribed.
    class Push < Base
      ZERO_SHA = /\A0+\z/
      BRANCH_PREFIX = "refs/heads/"

      def call
        return unless payload["ref"].to_s.start_with?(BRANCH_PREFIX)
        return untrack_branch!(branch) if payload["after"].to_s.match?(ZERO_SHA)

        track_or_update_branch
        payload.fetch("commits", []).each { link_commit(it) }
      end

      private

      def branch = payload["ref"].delete_prefix(BRANCH_PREFIX)

      def track_or_update_branch
        if payload["before"].to_s.match?(ZERO_SHA)
          track_branch!(branch, head_sha: payload["after"])
        else
          GiteaBranch.where(repository_html_url: repository["html_url"], name: branch)
                     .update_all(head_sha: payload["after"], updated_at: Time.current)
        end
      end

      def link_commit(commit)
        references = References.in_text(commit["message"])
        work_packages = references.work_packages(user)
        return if work_packages.empty?

        already_linked = GiteaCommit.find_by(html_url: commit["url"])&.work_packages.to_a
        GiteaCommit.upsert_from_push(commit, repository:, branch:, pusher:, work_packages:)
        comment!(work_packages - already_linked, references, :commit_pushed, **note_values(commit))
      end

      def note_values(commit)
        { commit: link(commit["id"].first(8), commit["url"]), branch: "`#{branch}`", quote: quote(commit["message"]) }
      end

      def pusher
        @pusher ||= GiteaUser.upsert_from_payload(payload["pusher"])
      end
    end
  end
end
