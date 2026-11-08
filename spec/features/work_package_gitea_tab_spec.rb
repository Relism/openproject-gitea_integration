# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe "Gitea tab on a work package", :js do
  shared_let(:project) { create(:project, enabled_module_names: %i[work_package_tracking gitea]) }
  shared_let(:work_package) { create(:work_package, project:, subject: "Checkout") }
  shared_let(:user) do
    permissions = %i[view_work_packages add_work_package_comments show_gitea_content]
    create(:user, member_with_permissions: { project => permissions })
  end

  let!(:pull_request) { create(:gitea_pull_request, work_packages: [work_package], title: "Add the checkout") }

  before { login_as(user) }

  def open_tab
    visit "/work_packages/#{work_package.id}/tabs/gitea"
    expect(page).to have_test_selector("op-work-package-gitea-tab-container", wait: 30)
  end

  it "shows linked items and counts them on the tab" do
    open_tab

    expect(page).to have_link("Add the checkout", href: pull_request.html_url)
    expect(page).to have_css(".op-tab-row--link_selected", text: /GITEA\s*1/i)
  end

  it "picks up new Gitea data without a reload" do
    stub_const("GiteaIntegration::WorkPackageTabComponent::REFRESH_INTERVAL", 500)
    open_tab

    create(:gitea_commit, work_packages: [work_package], message: "Pushed while watching")

    expect(page).to have_link("Pushed while watching", wait: 10)
  end

  it "offers git snippets" do
    open_tab

    click_on "Git snippets"

    within("#gitea-git-snippets-dialog") do
      expect(page).to have_text("#{work_package.type.name.downcase}/#{work_package.id}-checkout")
      expect(page).to have_text("OP##{work_package.id} Checkout")
    end
  end

  it "is hidden from users without the permission" do
    login_as(create(:user, member_with_permissions: { project => %i[view_work_packages] }))
    visit "/work_packages/#{work_package.id}/activity"

    expect(page).to have_css(".op-tab-row--link", text: /ACTIVITY/i, wait: 30)
    expect(page).to have_no_css(".op-tab-row--link", text: /GITEA/i)
  end
end
