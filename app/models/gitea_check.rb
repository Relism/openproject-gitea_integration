# frozen_string_literal: true

# A commit status (Gitea "status" event). Gitea Actions reports every job as one, so these
# also cover workflow jobs next to external CI. The latest status per context wins.
class GiteaCheck < ApplicationRecord
  STATES = %w[pending success error failure warning skipped].freeze

  validates :gitea_id, :repository_html_url, :sha, :context, presence: true
  validates :state, inclusion: { in: STATES }

  def self.upsert_from_payload(payload)
    check = find_or_initialize_by(repository_html_url: payload.dig("repository", "html_url"),
                                  sha: payload.fetch("sha"), context: payload.fetch("context"))
    return check if check.persisted? && check.gitea_id > payload.fetch("id")

    check.update!(gitea_id: payload["id"], state: payload["state"], description: payload["description"].presence,
                  target_url: payload["target_url"].presence,
                  gitea_updated_at: GiteaIntegration::Payload.time(payload["updated_at"]))
    check
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  # One state summarizing a set of checks, ordered from most to least alarming.
  def self.summary_state(checks)
    states = checks.map(&:state)
    %w[failure error pending warning success].find { states.include?(it) } || ("skipped" if states.any?)
  end

  def successful? = state.in?(%w[success skipped])
end
