# frozen_string_literal: true

module GiteaIntegration
  class CommitComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    alias_method :commit, :model
    options :items

    private

    def checks = items.checks_for(commit.repository_html_url, commit.sha)
  end
end
