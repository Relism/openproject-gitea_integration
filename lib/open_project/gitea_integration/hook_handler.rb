# frozen_string_literal: true

module OpenProject::GiteaIntegration
  # Entry point for POST /webhooks/gitea?key=<OpenProject API key>.
  # Forgejo sends the same payloads with X-Forgejo-* headers next to the X-Gitea-* ones.
  class HookHandler
    HANDLERS = {
      "push" => Handlers::Push,
      "create" => Handlers::BranchCreated,
      "delete" => Handlers::BranchDeleted,
      "pull_request" => Handlers::PullRequest,
      "pull_request_approved" => Handlers::PullRequestReview,
      "pull_request_rejected" => Handlers::PullRequestReview,
      "pull_request_comment" => Handlers::PullRequestReview,
      "issues" => Handlers::Issue,
      "issue_comment" => Handlers::Comment,
      "status" => Handlers::Status,
      "workflow_run" => Handlers::WorkflowRun
    }.freeze

    def process(request, params, user)
      event = header(request, "EVENT")
      return 400 if event.blank?
      return 403 unless authorized?(request, user)

      HANDLERS[event]&.new(payload(params), user:, event_type: header(request, "EVENT_TYPE"))&.call
      200
    end

    private

    def header(request, name)
      request.env["HTTP_X_GITEA_#{name}"].presence || request.env["HTTP_X_FORGEJO_#{name}"].presence
    end

    def payload(params)
      raw = params[:payload]
      raw.is_a?(String) ? JSON.parse(raw) : raw.permit!.to_h
    end

    def authorized?(request, user)
      user.present? && actor_allowed?(user) && valid_signature?(request)
    end

    def actor_allowed?(user)
      configured = OpenProject::GiteaIntegration.settings[:gitea_user_id].presence
      configured.nil? || user.id == configured.to_i
    end

    def valid_signature?(request)
      secret = OpenProject::GiteaIntegration.settings[:webhook_secret].presence
      return true if secret.nil?

      signature = header(request, "SIGNATURE")
      return false if signature.blank?

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, request.raw_post)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end
  end
end
