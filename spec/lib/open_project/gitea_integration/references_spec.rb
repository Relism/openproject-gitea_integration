# frozen_string_literal: true

require_relative "../../../spec_helper"

RSpec.describe OpenProject::GiteaIntegration::References do
  before { allow(Setting).to receive(:host_name).and_return("op.example.com") }

  describe ".in_text" do
    it "finds OP# references, URLs and semantic ids, without duplicates" do
      text = "OP#12 fixes OP#PROJ-7, see https://op.example.com/work_packages/12 and " \
             "http://op.example.com/sub/projects/x/wp/34. Also OP#12 again."

      expect(described_class.in_text(text).ids).to eq %w[12 PROJ-7 34]
    end

    it "treats PP# references as silent unless also referenced with OP#" do
      references = described_class.in_text("PP#1 PP#2", "OP#2")

      expect(references.ids).to contain_exactly("1", "2")
      expect(references.silent_ids).to eq %w[1]
    end

    it "ignores references glued to other words and URLs of other hosts" do
      text = "TOP#1 MOP#2 https://other.example.com/work_packages/3"

      expect(described_class.in_text(text).ids).to be_empty
    end

    it "copes with blank input" do
      expect(described_class.in_text(nil, "").ids).to be_empty
    end
  end

  describe ".in_branch" do
    {
      "feature/42-checkout" => %w[42],
      "42" => %w[42],
      "bugfix/proj-5-login" => %w[PROJ-5],
      "fix-the-proj-9-login" => %w[PROJ-9],
      "release-2026-notes" => %w[RELEASE-2026],
      "update-readme" => [],
      "main" => []
    }.each do |branch, ids|
      it "reads #{ids.inspect} from #{branch}" do
        expect(described_class.in_branch(branch).ids).to eq ids
      end
    end
  end

  describe "#work_packages" do
    shared_let(:project) { create(:project) }
    shared_let(:visible) { create(:work_package, project:) }
    shared_let(:other_project_wp) { create(:work_package) }
    shared_let(:user) do
      create(:user, member_with_permissions: { project => %i[view_work_packages add_work_package_comments] })
    end

    it "returns only work packages the user may comment on" do
      references = described_class.in_text("OP##{visible.id} OP##{other_project_wp.id}")

      expect(references.work_packages(user)).to eq [visible]
    end

    it "returns nothing without a user" do
      expect(described_class.in_text("OP##{visible.id}").work_packages(nil)).to be_empty
    end

    it "knows which work packages were referenced silently" do
      references = described_class.in_text("PP##{visible.id}")

      expect(references.silent?(visible)).to be true
    end
  end
end
