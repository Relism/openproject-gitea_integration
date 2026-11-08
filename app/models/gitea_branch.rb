# frozen_string_literal: true

class GiteaBranch < ApplicationRecord
  belongs_to :work_package
  belongs_to :gitea_user, optional: true

  validates :name, :repository, :repository_html_url, presence: true

  def self.track!(name:, repository:, work_package:, sender: nil, head_sha: nil)
    attributes = { work_package:, repository: repository["full_name"], default_branch: repository["default_branch"],
                   gitea_user: GiteaUser.upsert_from_payload(sender), head_sha: }.compact
    create_or_find_by!(repository_html_url: repository["html_url"], name:) { it.assign_attributes(attributes) }
      .tap { it.update!(attributes) }
  end

  def html_url = "#{repository_html_url}/src/branch/#{escaped(name)}"

  def compare_url
    return if default_branch.blank? || default_branch == name

    "#{repository_html_url}/compare/#{escaped(default_branch)}...#{escaped(name)}"
  end

  private

  def escaped(ref) = ref.split("/").map { ERB::Util.url_encode(it) }.join("/")
end
