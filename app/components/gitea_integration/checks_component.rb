# frozen_string_literal: true

module GiteaIntegration
  # Collapsible commit status list with a one-line summary, like a pull request's checks box on Gitea.
  class ChecksComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    alias_method :checks, :model

    def render? = checks.any?

    private

    def summary_status = Status.for(:check, GiteaCheck.summary_state(checks))

    def failing? = summary_status.code.in?(%w[failure error])

    def summary_text
      counts = checks.group_by { it.successful? ? :passed : it.state }.transform_values(&:count)
      return t(".all_passed", count: checks.size) if counts.keys == [:passed]

      counts.map { |state, count| t(".states.#{state}", count:) }.join(", ")
    end

    def check_status(check) = Status.for(:check, check.state)
  end
end
