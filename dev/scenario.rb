# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize

# The story both the demo seed and the fixture recorder play against a real Gitea:
# a feature branch that gets merged with green CI, a draft bugfix with failing CI,
# reviews, comments, an issue and a deleted branch. Every webhook OpenProject handles
# is triggered at least once.
#
# `refs` fills in the work package references:
#   seed:     { wp1: "12", wp2: "13", wp3: "14", host: "localhost:8080" }
#   recorder: { wp1: "${wp1}", ... } so the fixtures keep substitutable placeholders.
# `step` is called with a label around every action, letting the recorder name deliveries.
class Scenario
  WORKFLOW = <<~YAML
    name: CI
    on:
      push:
        branches: [main]
      pull_request:
    defaults:
      run:
        shell: sh
    jobs:
      build:
        runs-on: ubuntu-latest
        steps:
          - run: echo "Building ${{ github.ref_name }}"
      test:
        runs-on: ubuntu-latest
        needs: build
        steps:
          - name: Run test suite
            run: |
              case "${{ github.head_ref }}" in
                bugfix/*) echo "2 examples failed"; exit 1 ;;
              esac
              echo "All examples passed"
  YAML

  attr_reader :repo

  def initialize(gitea, refs:, repo: "dev/webshop", reviewer: "reviewer", step: ->(_label, &blk) { blk.call })
    @gitea = gitea
    @refs = refs
    @repo = repo
    @reviewer = reviewer
    @step = step
  end

  # Creates the repository, labels, the reviewer and the webhook; no deliveries yet.
  def prepare!(webhook_url:, webhook_secret:)
    owner, name = repo.split("/")
    @gitea.delete("/repos/#{repo}", allow: [404])
    @gitea.post("/user/repos", { name:, auto_init: true, default_branch: "main",
                                 description: "Demo shop wired to OpenProject" })
    @labels = {
      "feature" => @gitea.post("/repos/#{repo}/labels", { name: "feature", color: "#0e8a16" })["id"],
      "bug" => @gitea.post("/repos/#{repo}/labels", { name: "bug", color: "#d73a4a" })["id"]
    }
    ensure_reviewer!(owner)
    @gitea.post("/repos/#{repo}/hooks", {
                  type: "gitea", active: true, branch_filter: "*",
                  config: { url: webhook_url, content_type: "json", secret: webhook_secret },
                  events: %w[create delete push issues issue_comment issue_label
                             pull_request pull_request_label pull_request_comment pull_request_sync
                             pull_request_review_approved pull_request_review_rejected pull_request_review_comment
                             status workflow_run workflow_job]
                })
  end

  def play!
    feature_story!
    bugfix_story!
    issue_story!
  end

  private

  # A feature branch whose pull request gets approved, passes CI and is merged.
  def feature_story!
    step(:push_workflow) do
      @gitea.create_file(repo, ".gitea/workflows/ci.yaml", content: WORKFLOW, message: "Add CI workflow")
    end

    feature = "feature/#{ref(:wp1)}-checkout-flow"
    step(:branch_create) do
      @gitea.create_file(repo, "checkout.rb", branch: "main", new_branch: feature,
                                              content: "class Checkout; end\n",
                                              message: "Add checkout skeleton\n\nRefs OP##{ref(:wp1)}")
    end
    step(:push_url_reference) do
      @gitea.update_file(repo, "checkout.rb", branch: feature,
                                              content: "class Checkout\n  def pay = :ok\nend\n",
                                              message: "Wire payment provider\n\nhttp://#{ref(:host)}/wp/#{ref(:wp1)}")
    end

    pr = step(:pull_request_opened) do
      @gitea.post("/repos/#{repo}/pulls", { title: "Checkout flow OP##{ref(:wp1)}", head: feature, base: "main",
                                            body: "Implements the checkout.\n\nCloses OP##{ref(:wp1)}",
                                            labels: [@labels["feature"]] })
    end
    step(:pull_request_comment) do
      @gitea.post("/repos/#{repo}/issues/#{pr['number']}/comments",
                  { body: "This also touches the login redirect, see OP##{ref(:wp2)}" })
    end
    step(:pull_request_review_approved) do
      @gitea.post("/repos/#{repo}/pulls/#{pr['number']}/reviews", { event: "APPROVED", body: "Looks great!" },
                  sudo: @reviewer)
    end
    step(:status_success) do
      @gitea.post("/repos/#{repo}/statuses/#{pr.dig('head', 'sha')}",
                  { state: "success", context: "ci/external-lint", description: "No offenses",
                    target_url: "https://ci.example.com/builds/42" })
    end
    wait_for_actions
    step(:pull_request_merged) do
      @gitea.post("/repos/#{repo}/pulls/#{pr['number']}/merge", { Do: "merge" })
    end
    step(:branch_delete) { @gitea.delete("/repos/#{repo}/branches/#{URI.encode_www_form_component(feature)}") }
  end

  # A draft bugfix with failing CI that gets reviewed, closed and reopened.
  def bugfix_story!
    bugfix = "bugfix/#{ref(:wp2)}-login-redirect"
    step(:branch_create_bugfix) do
      @gitea.create_file(repo, "login.rb", branch: "main", new_branch: bugfix,
                                           content: "redirect_to :back\n",
                                           message: "Fix login redirect OP##{ref(:wp2)}")
    end
    draft = step(:pull_request_opened_draft) do
      @gitea.post("/repos/#{repo}/pulls", { title: "WIP: Fix login redirect", head: bugfix, base: "main",
                                            body: "Fixes OP##{ref(:wp2)}", labels: [@labels["bug"]] })
    end
    step(:pull_request_synchronized) do
      @gitea.update_file(repo, "login.rb", branch: bugfix, content: "redirect_to stored_location\n",
                                           message: "Redirect to the stored location\n\nRefs OP##{ref(:wp2)}")
    end
    step(:pull_request_review_comment) do
      @gitea.post("/repos/#{repo}/pulls/#{draft['number']}/reviews",
                  { event: "COMMENT", body: "What happens for anonymous users?" }, sudo: @reviewer)
    end
    step(:pull_request_edited) do
      @gitea.patch("/repos/#{repo}/pulls/#{draft['number']}", { title: "Fix login redirect" })
    end
    step(:pull_request_review_rejected) do
      @gitea.post("/repos/#{repo}/pulls/#{draft['number']}/reviews",
                  { event: "REQUEST_CHANGES", body: "Please add a regression test." }, sudo: @reviewer)
    end
    step(:pull_request_closed) do
      @gitea.patch("/repos/#{repo}/pulls/#{draft['number']}", { state: "closed" })
    end
    step(:pull_request_reopened) do
      @gitea.patch("/repos/#{repo}/pulls/#{draft['number']}", { state: "open" })
    end
    wait_for_actions
  end

  def issue_story!
    issue = step(:issue_opened) do
      @gitea.post("/repos/#{repo}/issues", { title: "Documentation is outdated OP##{ref(:wp3)}",
                                             body: "The README still describes the old checkout.",
                                             labels: [@labels["bug"]] })
    end
    step(:issue_comment) do
      @gitea.post("/repos/#{repo}/issues/#{issue['number']}/comments",
                  { body: "Tracked in OpenProject as OP##{ref(:wp3)}." })
    end
    step(:issue_closed) { @gitea.patch("/repos/#{repo}/issues/#{issue['number']}", { state: "closed" }) }
    step(:issue_reopened) { @gitea.patch("/repos/#{repo}/issues/#{issue['number']}", { state: "open" }) }
  end

  def step(label, &) = @step.call(label, &)

  def ref(key) = @refs.fetch(key)

  def ensure_reviewer!(owner)
    @gitea.post("/admin/users", { username: @reviewer, email: "#{@reviewer}@example.com", password: "reviewer123",
                                  must_change_password: false, full_name: "Rita Reviewer" }, allow: [422])
    @gitea.put("/repos/#{repo}/collaborators/#{@reviewer}", { permission: "write" }) unless owner == @reviewer
  end

  # Actions runs finish asynchronously; wait so their webhooks belong to the right part of the story.
  def wait_for_actions(timeout: 300)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    sleep 3
    until actions_runs&.then { |runs| runs.any? && runs.all? { it["status"] == "completed" } }
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        raise Gitea::Error, "Actions runs did not complete within #{timeout}s"
      end

      sleep 2
    end
  end

  # Gitea's SQLite answers 500 while the runner writes; treat that as "not done yet".
  def actions_runs
    @gitea.get("/repos/#{repo}/actions/runs").fetch("workflow_runs")
  rescue Gitea::Error
    nil
  end
end
# rubocop:enable Metrics/AbcSize
