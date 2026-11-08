# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe "Gitea models" do # rubocop:disable RSpec/DescribeClass
  describe GiteaIntegration::Payload do
    it "treats Go's zero time as unset" do
      expect(described_class.time("0001-01-01T00:00:00Z")).to be_nil
      expect(described_class.time("")).to be_nil
      expect(described_class.time("2026-11-07T18:00:00Z")).to eq Time.zone.parse("2026-11-07T18:00:00Z")
    end

    it "normalizes label colors" do
      expect(described_class.labels([{ "name" => "bug", "color" => "d73a4a" }, { "name" => "x", "color" => "#fff" }]))
        .to eq [{ "name" => "bug", "color" => "#d73a4a" }, { "name" => "x", "color" => "#fff" }]
    end
  end

  describe GiteaIntegration::Status do
    it "describes known states and falls back to a neutral one" do
      expect(described_class.for(:pull_request, "merged")).to have_attributes(icon: :"git-merge", hexcode: "#8250DF")
      expect(described_class.for(:check, "neutral")).to have_attributes(icon: :question, code: "neutral")
      expect(described_class.for(:issue, "open").css_class).to eq "__hl_background_muted __hl_gitea_issue_status_open"
    end
  end

  describe GiteaUser do
    it "upserts by profile URL" do
      payload = { "id" => 7, "login" => "ada", "full_name" => "", "html_url" => "https://g.example/ada",
                  "avatar_url" => "https://g.example/a.png" }

      user = described_class.upsert_from_payload(payload)
      expect(described_class.upsert_from_payload(payload.merge("full_name" => "Ada L."))).to eq user
      expect(user.reload).to have_attributes(display_name: "Ada L.", gitea_id: 7)
      expect(described_class.upsert_from_payload(nil)).to be_nil
    end
  end

  describe GiteaPullRequest do
    it "derives the state" do
      expect(described_class.state_from("state" => "closed", "merged" => true)).to eq "merged"
      expect(described_class.state_from("state" => "closed", "merged" => false)).to eq "closed"
      expect(described_class.state_from("state" => "open")).to eq "open"
    end

    it "accumulates work package links" do
      first, second = create_list(:work_package, 2)
      payload = gitea_payload("pull_request/pull_request_opened", wp1: first.id)

      described_class.upsert_from_payload(payload["pull_request"], repository: payload["repository"], work_packages: [first])
      record = described_class.upsert_from_payload(payload["pull_request"], repository: payload["repository"],
                                                                            work_packages: [second])

      expect(record.work_packages).to contain_exactly(first, second)
    end

    it "ignores payloads older than the stored state but keeps their links" do
      first, second = create_list(:work_package, 2)
      payload = gitea_payload("pull_request/pull_request_opened", wp1: first.id)
      newer = payload["pull_request"].merge("title" => "Renamed", "updated_at" => 1.hour.from_now.iso8601)

      described_class.upsert_from_payload(newer, repository: payload["repository"], work_packages: [first])
      record = described_class.upsert_from_payload(payload["pull_request"], repository: payload["repository"],
                                                                            work_packages: [second])

      expect(record.reload.title).to eq "Renamed"
      expect(record.work_packages).to contain_exactly(first, second)
    end
  end

  describe GiteaBranch do
    let(:branch) { build(:gitea_branch, name: "feature/12 ä", repository_html_url: "https://g.example/acme/shop") }

    it "builds Gitea URLs with escaped branch names" do
      expect(branch.html_url).to eq "https://g.example/acme/shop/src/branch/feature/12%20%C3%A4"
      expect(branch.compare_url).to eq "https://g.example/acme/shop/compare/main...feature/12%20%C3%A4"
    end

    it "offers no pull request for the default branch" do
      branch.name = "main"

      expect(branch.compare_url).to be_nil
    end
  end

  describe GiteaCheck do
    it "summarizes states by severity" do
      expect(described_class.summary_state(build_list(:gitea_check, 2, state: "success"))).to eq "success"
      expect(described_class.summary_state([build(:gitea_check, state: "success"), build(:gitea_check, state: "pending")]))
        .to eq "pending"
      expect(described_class.summary_state([build(:gitea_check, state: "pending"), build(:gitea_check, state: "failure")]))
        .to eq "failure"
      expect(described_class.summary_state([build(:gitea_check, state: "skipped")])).to eq "skipped"
      expect(described_class.summary_state([])).to be_nil
    end
  end

  describe GiteaWorkflowRun do
    it "shows the conclusion once completed" do
      expect(build(:gitea_workflow_run, status: "completed", conclusion: "failure").display_state).to eq "failure"
      expect(build(:gitea_workflow_run, status: "in_progress", conclusion: nil).display_state).to eq "in_progress"
    end

    it "knows its duration" do
      run = build(:gitea_workflow_run, started_at: 1.minute.ago, completed_at: Time.current)

      expect(run.duration).to be_within(1).of(60)
    end
  end
end
