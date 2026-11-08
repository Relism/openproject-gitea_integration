# frozen_string_literal: true

require_relative "../../../spec_helper"

# Every recorded Gitea delivery, end to end through the hook handler.
RSpec.describe OpenProject::GiteaIntegration::Handlers do
  shared_let(:project) { create(:project) }
  shared_let(:user) do
    create(:user, firstname: "Gitea", lastname: "Bot",
                  member_with_permissions: { project => %i[view_work_packages add_work_package_comments] })
  end
  shared_let(:wp1) { create(:work_package, project:) }
  shared_let(:wp2) { create(:work_package, project:) }
  shared_let(:wp3) { create(:work_package, project:) }

  def deliver(name, payload: nil) = deliver_gitea(name, user:, payload:, wp1: wp1.id, wp2: wp2.id, wp3: wp3.id)

  def notes(work_package) = work_package.journals.reload.filter_map(&:notes).compact_blank

  before { allow(Setting).to receive(:plugin_openproject_gitea_integration).and_return({}) }

  describe "push" do
    it "links referenced commits and comments once per work package" do
      expect(deliver("push/branch_create")).to eq 200

      commit = GiteaCommit.last
      expect(commit).to have_attributes(repository: "dev/webshop", branch: "feature/#{wp1.id}-checkout-flow",
                                        author_name: "dev", work_packages: [wp1])
      expect(commit.message).to start_with("Add checkout skeleton")
      expect(notes(wp1).last).to include("**Commit pushed:**", commit.short_sha, "`feature/#{wp1.id}-checkout-flow`",
                                         "> Add checkout skeleton")

      expect { deliver("push/branch_create") }.not_to(change { notes(wp1).size })
    end

    it "recognizes work package URLs in commit messages" do
      deliver("push/push_url_reference")

      expect(GiteaCommit.last.work_packages).to eq [wp1]
    end

    it "ignores commits without references" do
      expect { deliver("push/push_workflow") }.not_to change(GiteaCommit, :count)
    end

    it "tracks a branch named after a work package when it is pushed for the first time" do
      deliver("push/branch_create")

      expect(wp1.gitea_branches.sole).to have_attributes(name: "feature/#{wp1.id}-checkout-flow", default_branch: "main")
    end

    it "updates the head of a tracked branch and forgets it once deleted" do
      deliver("push/branch_create")
      payload = gitea_payload("push/push_url_reference", wp1: wp1.id, host: Setting.host_name)
      deliver("push/push_url_reference")
      expect(wp1.gitea_branches.sole.head_sha).to eq payload["after"]

      deliver("push/branch_create", payload: payload.merge("after" => "0" * 40, "commits" => []))
      expect(wp1.gitea_branches).to be_empty
    end

    it "does not comment for work packages the user may not comment on" do
      outsider = create(:work_package)
      payload = gitea_payload("push/branch_create", wp1: outsider.id)

      expect { deliver("push/branch_create", payload:) }.not_to change(GiteaCommit, :count)
      expect(notes(outsider)).to be_empty
    end

    it "links silently for PP# references" do
      payload = gitea_payload("push/branch_create", wp1: wp1.id)
      payload["commits"].first["message"] = "Quiet change PP##{wp1.id}"

      deliver("push/branch_create", payload:)

      expect(GiteaCommit.last.work_packages).to eq [wp1]
      expect(notes(wp1)).to be_empty
    end
  end

  describe "create and delete" do
    it "tracks and forgets branches" do
      deliver("create/branch_create")
      expect(wp1.gitea_branches.sole.repository).to eq "dev/webshop"

      deliver("delete/branch_delete")
      expect(wp1.gitea_branches.reload).to be_empty
    end

    it "ignores branches that reference no work package" do
      payload = gitea_payload("create/branch_create", wp1: wp1.id).merge("ref" => "chore/cleanup")

      expect { deliver("create/branch_create", payload:) }.not_to change(GiteaBranch, :count)
    end

    it "ignores tags" do
      payload = gitea_payload("create/branch_create", wp1: wp1.id).merge("ref_type" => "tag")

      expect { deliver("create/branch_create", payload:) }.not_to change(GiteaBranch, :count)
    end
  end

  describe "pull_request" do
    it "stores an opened pull request and comments on it" do
      deliver("pull_request/pull_request_opened")

      pull_request = wp1.gitea_pull_requests.sole
      expect(pull_request).to have_attributes(state: "open", draft: false, number: 1,
                                              title: "Checkout flow OP##{wp1.id}", repository: "dev/webshop",
                                              head_ref: "feature/#{wp1.id}-checkout-flow", base_ref: "main",
                                              labels: [{ "name" => "feature", "color" => "#0e8a16" }])
      expect(pull_request.gitea_user.login).to eq "dev"
      expect(notes(wp1).last).to include("**Pull request opened:**", "[#1 Checkout flow OP##{wp1.id}]")
    end

    it "marks draft pull requests" do
      deliver("pull_request/pull_request_opened_draft")

      expect(wp2.gitea_pull_requests.sole).to have_attributes(draft: true, display_state: "draft")
      expect(notes(wp2).last).to include("**Draft pull request opened:**")
    end

    it "records merges" do
      deliver("pull_request/pull_request_opened")
      deliver("pull_request/pull_request_merged")

      expect(wp1.gitea_pull_requests.sole).to have_attributes(state: "merged", merged_by: GiteaUser.find_by(login: "dev"))
      expect(notes(wp1).last).to include("**Pull request merged:**")
    end

    it "records closing and reopening" do
      deliver("pull_request/pull_request_closed")
      expect(wp2.gitea_pull_requests.sole.state).to eq "closed"
      expect(notes(wp2).last).to include("**Pull request closed:**")

      deliver("pull_request/pull_request_reopened")
      expect(wp2.gitea_pull_requests.sole.state).to eq "open"
      expect(notes(wp2).last).to include("**Pull request reopened:**")
    end

    it "only comments on work packages referenced for the first time by an update" do
      deliver("pull_request/pull_request_opened_draft")

      expect { deliver("pull_request/pull_request_edited") }.not_to(change { notes(wp2).size })
      expect(wp2.gitea_pull_requests.sole).to have_attributes(title: "Fix login redirect", draft: false)

      payload = gitea_payload("pull_request/pull_request_edited", wp2: wp2.id)
      payload["pull_request"]["body"] += " and OP##{wp3.id}"
      deliver("pull_request/pull_request_edited", payload:)
      expect(notes(wp3).sole).to include("**Referenced in pull request:**")
    end

    it "updates labels and the head commit without commenting" do
      deliver("pull_request/pull_request_opened")
      deliver("pull_request/pull_request_opened_draft")

      expect { deliver("pull_request/pull_request_opened.pull_request_label") }.not_to(change { notes(wp1).size })
      expect { deliver("pull_request/pull_request_synchronized.pull_request_sync") }.not_to(change { notes(wp2).size })
    end

    it "ignores pull requests that reference nothing and are unknown" do
      payload = gitea_payload("pull_request/pull_request_opened", wp1: wp1.id)
      payload["pull_request"].merge!("title" => "Unrelated", "body" => "")

      expect { deliver("pull_request/pull_request_opened", payload:) }.not_to change(GiteaPullRequest, :count)
    end
  end

  describe "reviews" do
    it "records approvals" do
      deliver("pull_request_approved/pull_request_review_approved")

      expect(wp1.gitea_pull_requests.sole).to have_attributes(review_state: "approved",
                                                              reviewed_by: GiteaUser.find_by(login: "reviewer"))
      expect(notes(wp1).last).to include("**Pull request approved:**", "> Looks great!")
    end

    it "records requested changes" do
      deliver("pull_request_rejected/pull_request_review_rejected")

      expect(wp2.gitea_pull_requests.sole.review_state).to eq "changes_requested"
      expect(notes(wp2).last).to include("**Changes requested:**", "> Please add a regression test.")
    end

    it "comments on reviews that only comment, keeping the review state" do
      deliver("pull_request_comment/pull_request_review_comment")

      expect(wp2.gitea_pull_requests.sole.review_state).to be_nil
      expect(notes(wp2).last).to include("**Pull request reviewed:**", "> What happens for anonymous users?")
    end
  end

  describe "issue_comment" do
    it "links a pull request to work packages a comment references" do
      deliver("issue_comment/pull_request_comment")

      expect(wp2.gitea_pull_requests.sole.number).to eq 1
      expect(notes(wp2).last).to include("**Commented on pull request:**", "#issuecomment-")
    end

    it "links an issue to work packages a comment references" do
      deliver("issue_comment/issue_comment")

      expect(wp3.gitea_issues.sole.number).to eq 3
      expect(notes(wp3).last).to include("**Commented on issue:**", "> Tracked in OpenProject")
    end

    it "ignores edited comments" do
      payload = gitea_payload("issue_comment/issue_comment", wp3: wp3.id).merge("action" => "edited")

      expect { deliver("issue_comment/issue_comment", payload:) }.not_to change(GiteaIssue, :count)
    end
  end

  describe "issues" do
    it "follows an issue through its states" do
      deliver("issues/issue_opened")
      expect(wp3.gitea_issues.sole).to have_attributes(state: "open", title: "Documentation is outdated OP##{wp3.id}",
                                                       labels: [{ "name" => "bug", "color" => "#d73a4a" }])
      expect(notes(wp3).last).to include("**Issue opened:**")

      deliver("issues/issue_closed")
      expect(wp3.gitea_issues.sole.state).to eq "closed"
      expect(notes(wp3).last).to include("**Issue closed:**")

      deliver("issues/issue_reopened")
      expect(notes(wp3).last).to include("**Issue reopened:**")

      expect { deliver("issues/issue_opened.issue_label") }.not_to(change { notes(wp3).size })
    end
  end

  describe "status" do
    it "keeps the latest state per commit and context" do
      deliver("status/ci_build_pull_request_success")
      deliver("status/ci_build_pull_request_pending")

      check = GiteaCheck.sole
      expect(check).to have_attributes(context: "CI / build (pull_request)", state: "success")
      expect(check.target_url).to include("/actions/runs/")
    end

    it "stores external commit statuses" do
      deliver("status/ci_external_lint_success")

      expect(GiteaCheck.sole).to have_attributes(context: "ci/external-lint", state: "success",
                                                 description: "No offenses",
                                                 target_url: "https://ci.example.com/builds/42")
    end
  end

  describe "workflow_run" do
    it "keeps the latest run state even when events arrive out of order" do
      completed = gitea_payload("workflow_run/completed_failure", wp2: wp2.id)
      late = completed.deep_dup.tap do |payload|
        payload["action"] = "in_progress"
        payload["workflow_run"].merge!("status" => "in_progress", "conclusion" => "")
      end

      deliver("workflow_run/completed_failure")
      deliver("workflow_run/completed_failure", payload: late)

      expect(GiteaWorkflowRun.sole).to have_attributes(workflow_name: "CI", status: "completed", conclusion: "failure",
                                                       event: "pull_request", display_state: "failure",
                                                       head_branch: "bugfix/#{wp2.id}-login-redirect")
    end

    it "stores push runs with their branch" do
      deliver("workflow_run/completed_success")

      expect(GiteaWorkflowRun.sole).to have_attributes(head_branch: "main", display_state: "success")
    end
  end
end
