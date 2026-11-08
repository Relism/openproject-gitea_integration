# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe GiteaIntegration::CleanupJob do
  it "removes unlinked items and stale CI results nothing shows" do
    work_package = create(:work_package)
    linked = create(:gitea_pull_request, work_packages: [work_package])
    create(:gitea_pull_request)
    create(:gitea_issue)
    create(:gitea_commit)
    shown_check = create(:gitea_check, sha: linked.head_sha, updated_at: 1.year.ago)
    create(:gitea_check, sha: "e" * 40, updated_at: 1.year.ago)
    fresh_check = create(:gitea_check, sha: "d" * 40)
    create(:gitea_workflow_run, head_sha: "c" * 40, head_branch: nil, updated_at: 1.year.ago)

    described_class.perform_now

    expect(GiteaPullRequest.all).to eq [linked]
    expect(GiteaIssue.count + GiteaCommit.count).to eq 0
    expect(GiteaCheck.all).to contain_exactly(shown_check, fresh_check)
    expect(GiteaWorkflowRun.count).to eq 0
  end
end
