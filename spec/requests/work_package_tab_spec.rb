# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe "Gitea work package tab", type: :rails_request do
  shared_let(:project) { create(:project, enabled_module_names: %i[work_package_tracking gitea]) }
  shared_let(:work_package) { create(:work_package, project:) }
  shared_let(:user) { create(:user, member_with_permissions: { project => %i[view_work_packages show_gitea_content] }) }
  shared_let(:pull_request) { create(:gitea_pull_request, work_packages: [work_package], title: "Linked PR") }

  let(:base) { "/projects/#{project.identifier}/work_packages/#{work_package.id}/gitea" }

  before { login_as(user) }

  it "renders the tab" do
    get "#{base}/tab"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Linked PR", "work-package-gitea-tab-content")
  end

  it "answers 204 to a poll while nothing changed and streams the tab otherwise" do
    digest = GiteaIntegration::LinkedItems.new(work_package).digest

    get "#{base}/refresh", params: { reference: digest }
    expect(response).to have_http_status(:no_content)

    get "#{base}/refresh", params: { reference: "outdated" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<turbo-stream", "Linked PR")
  end

  it "counts linked items" do
    get "#{base}/count"

    expect(response.parsed_body).to eq("count" => 1)
  end

  it "opens the git snippets dialog" do
    get "#{base}/git_snippets_dialog", headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("gitea-git-snippets-dialog")
  end

  context "without the permission" do
    let(:other) { create(:user, member_with_permissions: { project => %i[view_work_packages] }) }

    before { login_as(other) }

    it "is forbidden" do
      get "#{base}/tab"

      expect(response).to have_http_status(:forbidden)
    end
  end
end
