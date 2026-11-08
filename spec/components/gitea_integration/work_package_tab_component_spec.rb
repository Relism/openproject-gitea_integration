# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe GiteaIntegration::WorkPackageTabComponent, type: :component do
  shared_let(:project) { create(:project, identifier: "shop") }
  shared_let(:work_package) { create(:work_package, project:, subject: "Checkout") }

  subject(:rendered) { render_inline(described_class.new(work_package.reload)) }

  it "explains how to link items and shows an empty state per section" do
    rendered

    expect(page).to have_text("Mention OP##{work_package.id} in a Gitea title")
    expect(page).to have_css("clipboard-copy[value='OP##{work_package.id}']")
    %w[No\ pull\ requests No\ issues No\ branches No\ commits].each { expect(page).to have_text(it) }
    expect(page).to have_link("Git snippets", href: "/projects/shop/work_packages/#{work_package.id}/gitea/git_snippets_dialog")
  end

  it "polls for changes with the current digest" do
    rendered

    wrapper = page.find("[data-controller='poll-for-changes']")
    expect(wrapper["data-poll-for-changes-url-value"]).to eq "/projects/shop/work_packages/#{work_package.id}/gitea/refresh"
    expect(page).to have_css("[data-poll-for-changes-target='reference'][data-reference-value=" \
                             "'#{GiteaIntegration::LinkedItems.new(work_package).digest}']", visible: :all)
  end

  context "with linked items" do
    let!(:pull_request) do
      create(:gitea_pull_request, work_packages: [work_package], title: "Add checkout", number: 4, draft: true,
                                  labels: [{ "name" => "feature", "color" => "#0e8a16" }],
                                  review_state: "approved", reviewed_by: create(:gitea_user, name: "Rita"))
    end
    let!(:check) do
      create(:gitea_check, sha: pull_request.head_sha, context: "CI / test (pull_request)", state: "failure",
                           description: "Failing after 3s", target_url: "https://g.example/runs/1/jobs/1")
    end
    let!(:passing) { create(:gitea_check, sha: pull_request.head_sha, context: "ci/lint", state: "success") }
    let!(:issue) { create(:gitea_issue, work_packages: [work_package], title: "Docs outdated", state: "closed") }
    let!(:branch) { create(:gitea_branch, work_package:, name: "feature/#{work_package.id}-checkout") }
    let!(:run) { create(:gitea_workflow_run, head_branch: branch.name, run_number: 7, conclusion: "success") }
    let!(:commit) do
      create(:gitea_commit, work_packages: [work_package], message: "Wire payments\n\nLong body", author_name: "Ada")
    end

    before { rendered }

    it "shows pull requests with state, review, diff stats, labels and checks" do
      within_test_selector("gitea-pull-request") do |node|
        expect(node).to have_link("Add checkout", href: pull_request.html_url)
        expect(node).to have_text("Draft")
        expect(node).to have_text("acme/shop #4")
        expect(node).to have_text("Approved by Rita")
        expect(node).to have_text("feature")
        expect(node).to have_text("+10")
        expect(node).to have_text("3 files")
      end
    end

    it "expands failing checks with links to their details" do
      within_test_selector("gitea-checks") do |node|
        expect(node).to have_text("1 passed, 1 failing")
        expect(node).to have_link("Details", href: check.target_url)
        expect(node).to have_text("Failing after 3s")
      end
    end

    it "shows issues" do
      within_test_selector("gitea-issue") do |node|
        expect(node).to have_link("Docs outdated", href: issue.html_url)
        expect(node).to have_text("Closed")
      end
    end

    it "shows branches with their latest workflow run and a pull request shortcut" do
      within_test_selector("gitea-branch") do |node|
        expect(node).to have_link(branch.name, href: branch.html_url)
        expect(node).to have_link("Create pull request", href: branch.compare_url)
        expect(node).to have_link("CI #7: passed", href: run.html_url)
      end
    end

    it "shows the subject of commits" do
      within_test_selector("gitea-commit") do |node|
        expect(node).to have_link("Wire payments", href: commit.html_url)
        expect(node).to have_no_text("Long body")
        expect(node).to have_text("Authored by Ada")
      end
    end
  end

  def within_test_selector(name) = yield(page.find("[data-test-selector='#{name}']"))
end
