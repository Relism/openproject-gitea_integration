# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe "Work package API gitea link", type: :rails_request do
  shared_let(:project) { create(:project, enabled_module_names: %i[work_package_tracking gitea]) }
  shared_let(:work_package) { create(:work_package, project:) }

  def gitea_link_for(user)
    login_as(user)
    get "/api/v3/work_packages/#{work_package.id}"
    JSON.parse(response.body).dig("_links", "gitea") # rubocop:disable Rails/ResponseParsedBody -- parsed_body does not decode HAL+JSON
  end

  it "links the tab for users who may see Gitea content" do
    user = create(:user, member_with_permissions: { project => %i[view_work_packages show_gitea_content] })

    expect(gitea_link_for(user)).to include("href" => "/work_packages/#{work_package.id}/tabs/gitea")
  end

  it "hides the link from everybody else" do
    user = create(:user, member_with_permissions: { project => %i[view_work_packages] })

    expect(gitea_link_for(user)).to be_nil
  end
end
