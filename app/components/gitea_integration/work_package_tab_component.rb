# frozen_string_literal: true

module GiteaIntegration
  class WorkPackageTabComponent < ApplicationComponent
    include ApplicationHelper
    include OpPrimer::ComponentHelpers
    include OpTurbo::Streamable

    TURBO_FRAME_ID = "work-package-gitea-tab-content"
    REFRESH_INTERVAL = 15_000

    alias_method :work_package, :model

    def initialize(work_package, items: LinkedItems.new(work_package))
      super(work_package)
      @items = items
    end

    attr_reader :items

    private

    def linking_code = "OP##{work_package.display_id}"

    def branch_prefix = GitSnippetsDialogComponent.new(work_package).branch_prefix

    def path_params = { project_id: work_package.project.identifier, work_package_id: work_package.id }

    def poll_data
      {
        controller: "poll-for-changes",
        poll_for_changes_url_value: refresh_project_work_package_gitea_path(**path_params),
        poll_for_changes_interval_value: REFRESH_INTERVAL,
        poll_for_changes_continuous_value: true
      }
    end

    def sections
      [
        [:pull_requests, items.pull_requests, :"git-pull-request", PullRequestComponent, { code: linking_code }],
        [:issues, items.issues, :"issue-opened", IssueComponent, { code: linking_code }],
        [:branches, items.branches, :"git-branch", BranchComponent, { code: "#{branch_prefix}-…" }],
        [:commits, items.commits, :"git-commit", CommitComponent, { code: linking_code }]
      ]
    end

    def code(text) = content_tag(:code, text)
  end
end
