# frozen_string_literal: true

module GiteaIntegration
  # Records identified by their Gitea URL that accumulate work package links over time.
  module LinksWorkPackages
    extend ActiveSupport::Concern

    included do
      has_and_belongs_to_many :work_packages # rubocop:disable Rails/HasAndBelongsToMany

      scope :without_work_package, -> { where.missing(:work_packages) }
    end

    class_methods do
      # Gitea delivers webhooks concurrently, so a payload older than the stored state only adds links.
      def upsert_linking!(html_url, attributes, work_packages)
        create_or_find_by!(html_url:) { it.assign_attributes(attributes) }.tap do |record|
          record.update!(attributes) unless stale?(record, attributes)
          record.work_packages |= work_packages
        end
      end

      private

      def stale?(record, attributes)
        stored = record.try(:gitea_updated_at)
        incoming = attributes[:gitea_updated_at]
        stored.present? && incoming.present? && incoming < stored
      end
    end
  end
end
