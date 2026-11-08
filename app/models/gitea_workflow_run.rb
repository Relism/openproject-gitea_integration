# frozen_string_literal: true

class GiteaWorkflowRun < ApplicationRecord
  STATUS_ORDER = %w[queued waiting requested in_progress completed].freeze

  belongs_to :gitea_user, optional: true

  validates :gitea_id, :html_url, :repository_html_url, :workflow_name, :head_sha, :status, presence: true

  # Gitea delivers run events concurrently, so an "in_progress" may arrive after "completed".
  def self.upsert_from_payload(payload)
    run = payload.fetch("workflow_run")
    record = find_or_initialize_by(html_url: run.fetch("html_url"))
    updated_at = GiteaIntegration::Payload.time(run["updated_at"])
    return record if record.persisted? && newer?(record, updated_at, run["status"])

    record.tap { it.update!(attributes_from(payload)) }
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def self.attributes_from(payload) # rubocop:disable Metrics/AbcSize
    run = payload.fetch("workflow_run")
    {
      gitea_id: run["id"],
      repository_html_url: payload.dig("repository", "html_url"),
      workflow_name: payload.dig("workflow", "name").presence || run["path"].to_s.split("@").first,
      display_title: run["display_title"],
      event: run["event"],
      run_number: run["run_number"],
      head_sha: run["head_sha"],
      head_branch: run["head_branch"].presence || run.dig("pull_requests", 0, "head", "ref"),
      status: run["status"],
      conclusion: run["conclusion"].presence,
      started_at: GiteaIntegration::Payload.time(run["started_at"]),
      completed_at: GiteaIntegration::Payload.time(run["completed_at"]),
      gitea_updated_at: GiteaIntegration::Payload.time(run["updated_at"]),
      gitea_user: GiteaUser.upsert_from_payload(run["trigger_actor"] || run["actor"])
    }
  end

  def self.newer?(record, updated_at, status)
    stored = [record.gitea_updated_at.to_i, STATUS_ORDER.index(record.status).to_i]
    (stored <=> [updated_at.to_i, STATUS_ORDER.index(status).to_i]).positive?
  end

  def completed? = status == "completed"

  def duration
    return unless started_at && completed_at

    completed_at - started_at
  end

  # The state shown to users: the conclusion once finished, the status while running.
  def display_state = completed? ? conclusion.presence || "success" : status
end
