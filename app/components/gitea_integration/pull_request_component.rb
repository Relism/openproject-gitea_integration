# frozen_string_literal: true

module GiteaIntegration
  class PullRequestComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    alias_method :pull_request, :model
    options :items

    private

    def status = Status.for(:pull_request, pull_request.display_state)

    def review_status = pull_request.review_state && Status.for(:review, pull_request.review_state)

    def checks = items.checks_for(pull_request.repository_html_url, pull_request.head_sha)

    def meta
      user, key, time = if pull_request.merged?
                          [pull_request.merged_by, ".merged_by", pull_request.merged_at]
                        else
                          [pull_request.gitea_user, ".opened_by", pull_request.gitea_updated_at]
                        end
      { user:, time:, text: t(key, name: user&.display_name) }
    end

    def diff_stats?
      pull_request.additions || pull_request.deletions
    end
  end
end
