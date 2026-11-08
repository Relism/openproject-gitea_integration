# frozen_string_literal: true

require_relative "../../../spec_helper"

RSpec.describe OpenProject::GiteaIntegration::HookHandler do
  shared_let(:project) { create(:project) }
  shared_let(:work_package) { create(:work_package, project:) }
  shared_let(:user) do
    create(:user, member_with_permissions: { project => %i[view_work_packages add_work_package_comments] })
  end

  let(:settings) { {} }
  let(:secret) { nil }
  let(:headers) { {} }
  let(:request) { gitea_request("push/branch_create", secret:, headers:, wp1: work_package.id) }
  let(:params) { ActionController::Parameters.new(payload: JSON.parse(request.raw_post)) }

  subject(:status) { described_class.new.process(request, params, user) }

  before { allow(Setting).to receive(:plugin_openproject_gitea_integration).and_return(settings) }

  it "processes known events" do
    expect { expect(status).to eq 200 }.to change(GiteaCommit, :count).by(1)
  end

  context "without an authenticated user" do
    subject(:status) { described_class.new.process(request, params, nil) }

    it { is_expected.to eq 403 }
  end

  context "when an actor is configured" do
    let(:settings) { { "gitea_user_id" => create(:user).id.to_s } }

    it "rejects every other user" do
      expect(status).to eq 403
    end
  end

  context "when a secret is configured" do
    let(:settings) { { "webhook_secret" => "s3cret" } }

    context "with a valid signature" do
      let(:secret) { "s3cret" }

      it { is_expected.to eq 200 }
    end

    context "with a wrong signature" do
      let(:secret) { "guess" }

      it { is_expected.to eq 403 }
    end

    context "without a signature" do
      it { is_expected.to eq 403 }
    end

    context "with Forgejo headers" do
      let(:request) do
        req = gitea_request("push/branch_create", secret: "s3cret", wp1: work_package.id)
        req.env["HTTP_X_FORGEJO_SIGNATURE"] = req.env.delete("HTTP_X_GITEA_SIGNATURE")
        req.env["HTTP_X_FORGEJO_EVENT"] = req.env.delete("HTTP_X_GITEA_EVENT")
        req
      end

      it { is_expected.to eq 200 }
    end
  end

  context "without an event header" do
    let(:headers) { { "X-Gitea-Event" => "" } }

    it { is_expected.to eq 400 }
  end

  context "with an event the integration does not use" do
    let(:request) { gitea_request("workflow_job/completed_success") }

    it "accepts it without storing anything" do
      expect { expect(status).to eq 200 }.not_to change(GiteaWorkflowRun, :count)
    end
  end

  context "with a form-encoded payload" do
    let(:params) { ActionController::Parameters.new(payload: request.raw_post) }

    it "parses the payload field" do
      expect { expect(status).to eq 200 }.to change(GiteaCommit, :count).by(1)
    end
  end
end
