# frozen_string_literal: true

class GiteaCommit < ApplicationRecord
  include GiteaIntegration::LinksWorkPackages

  belongs_to :gitea_user, optional: true

  validates :sha, :html_url, :repository, :repository_html_url, :authored_at, presence: true

  def self.upsert_from_push(commit, repository:, branch:, pusher:, work_packages: [])
    attributes = {
      sha: commit.fetch("id"),
      repository: repository["full_name"],
      repository_html_url: repository["html_url"],
      branch:,
      message: commit["message"].to_s.strip,
      author_name: commit.dig("author", "name"),
      author_email: commit.dig("author", "email"),
      authored_at: GiteaIntegration::Payload.time(commit["timestamp"]) || Time.current,
      gitea_user: pusher
    }
    upsert_linking!(commit.fetch("url"), attributes, work_packages)
  end

  def short_sha = sha.first(8)

  def subject = message.lines.first.to_s.strip
end
