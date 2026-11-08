# frozen_string_literal: true

class GiteaPullRequest < ApplicationRecord
  include GiteaIntegration::LinksWorkPackages

  belongs_to :gitea_user, optional: true
  belongs_to :merged_by, class_name: "GiteaUser", optional: true
  belongs_to :reviewed_by, class_name: "GiteaUser", optional: true

  enum :state, { open: "open", closed: "closed", merged: "merged" }, validate: true
  enum :review_state, { approved: "approved", changes_requested: "changes_requested" }, prefix: :review

  validates :gitea_id, :number, :html_url, :repository, :repository_html_url, :title, presence: true

  def self.upsert_from_payload(pull_request, repository:, work_packages: [])
    upsert_linking!(pull_request.fetch("html_url"), attributes_from(pull_request, repository), work_packages)
  end

  def self.attributes_from(pull_request, repository) # rubocop:disable Metrics/AbcSize
    {
      gitea_id: pull_request["id"],
      number: pull_request["number"],
      repository: repository["full_name"],
      repository_html_url: repository["html_url"],
      state: state_from(pull_request),
      draft: pull_request["draft"] == true,
      title: pull_request["title"],
      body: pull_request["body"],
      labels: GiteaIntegration::Payload.labels(pull_request["labels"]),
      head_ref: pull_request.dig("head", "ref"),
      head_sha: pull_request.dig("head", "sha"),
      base_ref: pull_request.dig("base", "ref"),
      additions: pull_request["additions"],
      deletions: pull_request["deletions"],
      changed_files: pull_request["changed_files"],
      comments_count: pull_request["comments"],
      gitea_user: GiteaUser.upsert_from_payload(pull_request["user"]),
      merged_by: GiteaUser.upsert_from_payload(pull_request["merged_by"]),
      merged_at: GiteaIntegration::Payload.time(pull_request["merged_at"]),
      closed_at: GiteaIntegration::Payload.time(pull_request["closed_at"]),
      gitea_created_at: GiteaIntegration::Payload.time(pull_request["created_at"]),
      gitea_updated_at: GiteaIntegration::Payload.time(pull_request["updated_at"])
    }
  end

  def self.state_from(pull_request)
    return "merged" if pull_request["merged"]

    pull_request["state"] == "closed" ? "closed" : "open"
  end

  def display_state
    open? && draft? ? "draft" : state
  end
end
