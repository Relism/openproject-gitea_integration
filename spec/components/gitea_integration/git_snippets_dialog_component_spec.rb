# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe GiteaIntegration::GitSnippetsDialogComponent, type: :component do
  let(:type) { build_stubbed(:type, name: "User Story") }
  let(:work_package) { build_stubbed(:work_package, id: 42, type:, subject: "Pay & ship it's done!") }

  subject(:component) { described_class.new(work_package) }

  it "suggests a branch name that Gitea links back to the work package" do
    expect(component.branch_name).to eq "user-story/42-pay-and-ship-it-s-done"
    expect(OpenProject::GiteaIntegration::References.in_branch(component.branch_name).ids).to eq %w[42]
  end

  it "suggests a referencing commit message and a shell-safe command" do
    expect(component.commit_message).to start_with("OP#42 Pay & ship it's done!\n\n")
    expect(component.create_branch_command)
      .to start_with("git switch -c user-story/42-pay-and-ship-it-s-done && git commit --allow-empty -m OP\\#42\\ Pay")
  end

  it "renders all snippets" do
    render_inline(component)

    %w[branch_name commit_message create_branch_command].each do |key|
      expect(page).to have_css("[data-test-selector='gitea-snippet-#{key}']")
    end
  end
end
