# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe "Gitea admin settings", :skip_csrf, type: :rails_request do
  shared_let(:admin) { create(:admin) }

  it "shows setup instructions and stores the settings" do
    login_as(admin)
    actor = create(:user)

    get "/gitea_integration/admin/settings"
    expect(response.body).to include("Connect a Gitea or Forgejo", "webhooks/gitea?key=", "No webhook secret is configured")

    patch "/gitea_integration/admin/settings", params: { gitea_user_id: actor.id, webhook_secret: "s3cret" }
    expect(response).to redirect_to("/gitea_integration/admin/settings")
    expect(OpenProject::GiteaIntegration.settings).to include("gitea_user_id" => actor.id.to_s, "webhook_secret" => "s3cret")
  end

  it "is limited to administrators" do
    login_as(create(:user))

    get "/gitea_integration/admin/settings"

    expect(response).to have_http_status(:forbidden)
  end
end
