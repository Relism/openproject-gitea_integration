# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe "POST /webhooks/gitea", type: :rails_request do
  shared_let(:project) { create(:project) }
  shared_let(:work_package) { create(:work_package, project:) }
  shared_let(:bot) do
    create(:user, member_with_permissions: { project => %i[view_work_packages add_work_package_comments] })
  end
  shared_let(:api_token) { Token::API.create!(user: bot).plain_value }

  let(:delivery) { gitea_request("pull_request/pull_request_opened", secret: "s3cret", wp1: work_package.id) }
  let(:headers) do
    delivery.env.select { |key, _| key.start_with?("HTTP_X_") }.merge("CONTENT_TYPE" => "application/json")
  end

  before do
    Setting.plugin_openproject_gitea_integration = { "gitea_user_id" => bot.id.to_s, "webhook_secret" => "s3cret" }
  end

  it "links the pull request and comments as the bot" do
    post "/webhooks/gitea?key=#{api_token}", params: delivery.raw_post, headers: headers

    expect(response).to have_http_status(:ok)
    expect(work_package.gitea_pull_requests.count).to eq 1
    expect(work_package.journals.last).to have_attributes(user: bot)
  end

  it "rejects requests without the API key" do
    post "/webhooks/gitea", params: delivery.raw_post, headers: headers

    expect(response).not_to be_successful
    expect(GiteaPullRequest.count).to eq 0
  end

  it "rejects requests with a forged signature" do
    forged = headers.merge("HTTP_X_GITEA_SIGNATURE" => "0" * 64)
    post "/webhooks/gitea?key=#{api_token}", params: delivery.raw_post, headers: forged

    expect(response).to have_http_status(:forbidden)
    expect(GiteaPullRequest.count).to eq 0
  end
end
