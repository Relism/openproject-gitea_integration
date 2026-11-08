# frozen_string_literal: true

module GiteaIntegration
  # Drops records no work package links to anymore, and CI results that nothing in OpenProject shows.
  class CleanupJob < ApplicationJob
    CI_RETENTION = 30.days

    priority_number :low

    def perform
      [GiteaPullRequest, GiteaIssue, GiteaCommit].each { it.without_work_package.find_each(&:destroy!) }

      stale_checks.delete_all
      stale_workflow_runs.delete_all
    end

    private

    def stale_checks
      GiteaCheck.where(updated_at: ...CI_RETENTION.ago)
                .where.not(sha: pull_request_heads)
                .where.not(sha: GiteaCommit.select(:sha))
    end

    def stale_workflow_runs
      GiteaWorkflowRun.where(updated_at: ...CI_RETENTION.ago)
                      .where.not(head_sha: pull_request_heads)
                      .where.not(head_sha: GiteaCommit.select(:sha))
                      .where("head_branch IS NULL OR head_branch NOT IN (?)", GiteaBranch.select(:name))
    end

    def pull_request_heads = GiteaPullRequest.where.not(head_sha: nil).select(:head_sha)
  end
end
