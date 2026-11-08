# frozen_string_literal: true

FactoryBot.define do
  factory :gitea_user do
    sequence(:gitea_id)
    sequence(:login) { |n| "gitea_user_#{n}" }
    name { "Gitea #{login}" }
    html_url { "https://gitea.example.com/#{login}" }
    avatar_url { "https://gitea.example.com/avatars/#{login}" }
  end

  factory :gitea_pull_request do
    gitea_user
    sequence(:gitea_id)
    sequence(:number)
    repository { "acme/shop" }
    repository_html_url { "https://gitea.example.com/acme/shop" }
    html_url { "#{repository_html_url}/pulls/#{number}" }
    state { "open" }
    title { "Pull request #{number}" }
    body { "Body" }
    head_ref { "feature/#{number}" }
    sequence(:head_sha) { |n| format("%040x", n) }
    base_ref { "main" }
    additions { 10 }
    deletions { 2 }
    changed_files { 3 }
    gitea_updated_at { Time.current }

    trait :merged do
      state { "merged" }
      merged_by factory: :gitea_user
      merged_at { Time.current }
    end
  end

  factory :gitea_issue do
    gitea_user
    sequence(:gitea_id)
    sequence(:number)
    repository { "acme/shop" }
    repository_html_url { "https://gitea.example.com/acme/shop" }
    html_url { "#{repository_html_url}/issues/#{number}" }
    state { "open" }
    title { "Issue #{number}" }
    gitea_updated_at { Time.current }
  end

  factory :gitea_branch do
    work_package
    gitea_user
    sequence(:name) { |n| "feature/#{n}-branch" }
    repository { "acme/shop" }
    repository_html_url { "https://gitea.example.com/acme/shop" }
    default_branch { "main" }
  end

  factory :gitea_commit do
    sequence(:sha) { |n| format("%040x", 1000 + n) }
    repository { "acme/shop" }
    repository_html_url { "https://gitea.example.com/acme/shop" }
    html_url { "#{repository_html_url}/commit/#{sha}" }
    branch { "main" }
    message { "Do the thing\n\nRefs OP#1" }
    author_name { "Ada" }
    author_email { "ada@example.com" }
    authored_at { Time.current }
  end

  factory :gitea_check do
    sequence(:gitea_id)
    repository_html_url { "https://gitea.example.com/acme/shop" }
    sha { format("%040x", 1) }
    sequence(:context) { |n| "ci/job-#{n}" }
    state { "success" }
    target_url { "https://ci.example.com/1" }
  end

  factory :gitea_workflow_run do
    sequence(:gitea_id)
    sequence(:run_number)
    repository_html_url { "https://gitea.example.com/acme/shop" }
    html_url { "#{repository_html_url}/actions/runs/#{gitea_id}" }
    workflow_name { "CI" }
    head_sha { format("%040x", 1) }
    head_branch { "main" }
    status { "completed" }
    conclusion { "success" }
    gitea_updated_at { Time.current }
  end
end
