# frozen_string_literal: true

module OpenProject::GiteaIntegration
  module Handlers
    class Status < Base
      def call = GiteaCheck.upsert_from_payload(payload)
    end
  end
end
