# frozen_string_literal: true

module OpenProject::GiteaIntegration
  module Handlers
    class Base
      Linked = Data.define(:record, :references, :work_packages, :newly_linked)

      def initialize(payload, user:, event_type: nil)
        @payload = payload
        @user = user
        @event_type = event_type
      end

      private

      attr_reader :payload, :user, :event_type

      def repository = payload.fetch("repository")

      def sender = payload["sender"] || {}

      # Upserts an issue or pull request referenced from its title or description, or known already.
      def link!(model, item, text: [item["title"], item["body"]])
        references = References.in_text(*text)
        work_packages = references.work_packages(user)
        existing = model.find_by(html_url: item["html_url"])
        return if work_packages.empty? && existing.nil?

        already_linked = existing&.work_packages.to_a
        record = model.upsert_from_payload(item, repository:, work_packages:)
        Linked.new(record:, references:, work_packages:, newly_linked: work_packages - already_linked)
      end

      # Posts a journal note on every referenced work package except the silently (PP#) referenced ones.
      def comment!(work_packages, references, key, **values)
        notes = I18n.t("gitea_integration.journal.#{key}", user: sender_link, repository: repository_link, **values)

        work_packages.reject { references.silent?(it) }.each do |work_package|
          ::AddWorkPackageNoteService.new(user:, work_package:).call(notes, send_notifications: false)
        end
      end

      def sender_link = link(sender["full_name"].presence || sender["login"], sender["html_url"])

      def repository_link = link(repository["full_name"], repository["html_url"])

      def link(text, url)
        label = text.to_s.gsub(/[\[\]]/) { "\\#{it}" }
        url.present? ? "[#{label}](#{url})" : label
      end

      def item_link(item) = link("##{item['number']} #{item['title']}", item["html_url"])

      def quote(text)
        return "" if text.blank?

        "\n\n#{text.strip.lines.map { "> #{it}" }.join}"
      end

      def track_branch!(name, head_sha: nil)
        work_package = References.in_branch(name).work_packages(user).first
        return if work_package.nil?

        GiteaBranch.track!(name:, repository:, work_package:, sender:, head_sha:)
      end

      def untrack_branch!(name)
        GiteaBranch.where(repository_html_url: repository["html_url"], name:).destroy_all
      end
    end
  end
end
