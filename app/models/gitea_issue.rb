# frozen_string_literal: true

class GiteaIssue < ApplicationRecord
  include GiteaIntegration::LinksWorkPackages

  belongs_to :gitea_user, optional: true

  enum :state, { open: "open", closed: "closed" }, validate: true

  validates :gitea_id, :number, :html_url, :repository, :repository_html_url, :title, presence: true

  def self.upsert_from_payload(issue, repository:, work_packages: [])
    upsert_linking!(issue.fetch("html_url"), attributes_from(issue, repository), work_packages)
  end

  def self.attributes_from(issue, repository) # rubocop:disable Metrics/AbcSize
    {
      gitea_id: issue["id"],
      number: issue["number"],
      repository: repository["full_name"],
      repository_html_url: repository["html_url"],
      state: issue["state"] == "closed" ? "closed" : "open",
      title: issue["title"],
      body: issue["body"],
      labels: GiteaIntegration::Payload.labels(issue["labels"]),
      comments_count: issue["comments"],
      gitea_user: GiteaUser.upsert_from_payload(issue["user"]),
      closed_at: GiteaIntegration::Payload.time(issue["closed_at"]),
      gitea_created_at: GiteaIntegration::Payload.time(issue["created_at"]),
      gitea_updated_at: GiteaIntegration::Payload.time(issue["updated_at"])
    }
  end
end
