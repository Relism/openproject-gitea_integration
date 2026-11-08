# frozen_string_literal: true

module GiteaIntegration
  class BranchComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    alias_method :branch, :model
    options :items

    private

    def latest_run = items.latest_run_for(branch)

    def run_status = Status.for(:check, latest_run.display_state)

    def run_label
      t(".workflow_run", name: latest_run.workflow_name, number: latest_run.run_number,
                         state: t(".run_states.#{latest_run.display_state}"))
    end
  end
end
