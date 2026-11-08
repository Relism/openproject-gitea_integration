# frozen_string_literal: true

class GiteaUser < ApplicationRecord
  validates :gitea_id, :login, :html_url, presence: true

  def self.upsert_from_payload(user)
    return if user.blank? || user["html_url"].blank?

    attributes = { gitea_id: user["id"], login: user["login"].presence || user["username"],
                   name: user["full_name"].presence, avatar_url: user["avatar_url"].presence }
    create_or_find_by!(html_url: user["html_url"]) { it.assign_attributes(attributes) }
      .tap { it.update!(attributes) }
  end

  def display_name = name.presence || login
end
