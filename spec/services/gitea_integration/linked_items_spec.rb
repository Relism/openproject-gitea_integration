# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe GiteaIntegration::LinkedItems do
  shared_let(:work_package) { create(:work_package) }

  subject(:items) { described_class.new(work_package.reload) }

  it "lists open pull requests first" do
    merged = create(:gitea_pull_request, :merged, work_packages: [work_package])
    open = create(:gitea_pull_request, work_packages: [work_package])

    expect(items.pull_requests).to eq [open, merged]
  end

  it "counts every linked item" do
    create(:gitea_pull_request, work_packages: [work_package])
    create(:gitea_issue, work_packages: [work_package])
    create(:gitea_branch, work_package:)
    create(:gitea_commit, work_packages: [work_package])

    expect(items.count).to eq 4
  end

  it "finds checks of shown pull requests and commits, and the latest run of a branch" do
    pull_request = create(:gitea_pull_request, work_packages: [work_package])
    check = create(:gitea_check, sha: pull_request.head_sha, repository_html_url: pull_request.repository_html_url)
    create(:gitea_check, sha: "f" * 40)
    branch = create(:gitea_branch, work_package:, name: "feature/x")
    create(:gitea_workflow_run, head_branch: "feature/x", gitea_id: 1)
    latest = create(:gitea_workflow_run, head_branch: "feature/x", gitea_id: 2)

    expect(items.checks_for(pull_request.repository_html_url, pull_request.head_sha)).to eq [check]
    expect(items.latest_run_for(branch)).to eq latest
  end

  it "changes its digest whenever shown data changes" do
    pull_request = create(:gitea_pull_request, work_packages: [work_package])
    before = described_class.new(work_package).digest
    expect(described_class.new(work_package).digest).to eq before

    create(:gitea_check, sha: pull_request.head_sha, repository_html_url: pull_request.repository_html_url)
    expect(described_class.new(work_package).digest).not_to eq before
  end
end
