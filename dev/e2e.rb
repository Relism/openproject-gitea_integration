# frozen_string_literal: true

# End-to-end check of the seeded demo stack (run by `bin/dev e2e` via `rails runner`):
# verifies what the seed story left in OpenProject, then pushes a fresh commit to Gitea and
# waits for the webhook to link it.
require_relative "gitea"

failures = 0
check = lambda do |label, ok|
  puts "#{ok ? '✓' : '✗'} #{label}"
  failures += 1 unless ok
end

project = Project.find_by(identifier: "webshop") or abort("✗ Demo not seeded; run bin/dev up first.")
wp1, wp2, wp3 = project.work_packages.reorder(:id).first(3)
notes = ->(wp) { wp.journals.reload.filter_map(&:notes).compact_blank }

pr1 = wp1.gitea_pull_requests.first
check.("merged pull request linked to ##{wp1.id}", pr1&.merged?)
check.("its checks recorded (Actions jobs and external CI)", GiteaCheck.where(sha: pr1&.head_sha).count >= 3)
check.("commits linked to ##{wp1.id}", wp1.gitea_commits.count >= 2)
check.("journal notes on ##{wp1.id}",
       %w[Commit\ pushed Pull\ request\ opened Pull\ request\ approved Pull\ request\ merged]
         .all? { |kind| notes.(wp1).any? { it.include?("**#{kind}:**") } })

pr2 = wp2.gitea_pull_requests.find_by(number: 2)
check.("open, ready pull request with requested changes on ##{wp2.id}",
       pr2&.open? && !pr2.draft? && pr2.review_changes_requested?)
check.("failing CI on that pull request", GiteaCheck.exists?(sha: pr2&.head_sha, state: "failure"))
check.("tracked branch with a workflow run on ##{wp2.id}",
       (branch = wp2.gitea_branches.first) && GiteaWorkflowRun.exists?(head_branch: branch.name))
check.("open issue linked to ##{wp3.id}", wp3.gitea_issues.first&.open?)

gitea = Gitea.new(url: ENV.fetch("GITEA_URL", "http://gitea:3000"), user: "dev", password: "devdevdev")
token = gitea.post("/users/dev/tokens", { name: "e2e-#{Time.now.to_i}", scopes: ["all"] }).fetch("sha1")
gitea = Gitea.new(url: ENV.fetch("GITEA_URL", "http://gitea:3000"), token:)
message = "e2e #{SecureRandom.hex(4)} OP##{wp3.id}"
gitea.create_file("dev/webshop", "e2e/#{SecureRandom.hex(4)}.txt", content: "e2e\n", message:)

linked = 30.times.any? do
  sleep 1
  wp3.gitea_commits.reload.any? { it.message == message }
end
check.("live push reaches OpenProject within 30 s", linked)

abort("\n#{failures} check(s) failed.") if failures.positive?
puts "\nAll end-to-end checks passed."
