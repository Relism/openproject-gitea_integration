# frozen_string_literal: true

# Replays deliveries recorded from a real Gitea (spec/fixtures/gitea_webhooks, see bin/dev record).
module GiteaWebhooks
  FIXTURES = File.expand_path("../fixtures/gitea_webhooks", __dir__)

  # The recorded payload with ${wp1}-style placeholders replaced.
  def gitea_fixture(name, **replacements)
    defaults = { host: Setting.host_name }
    raw = File.read(File.join(FIXTURES, "#{name}.json"))
               .gsub(/\$\{(\w+)\}/) { defaults.merge(replacements).fetch($1.to_sym).to_s }
    JSON.parse(raw)
  end

  def gitea_payload(name, **) = gitea_fixture(name, **).fetch("payload")

  # A request as Gitea would send it, signed with `secret` when given.
  def gitea_request(name, secret: nil, headers: {}, payload: nil, **replacements)
    fixture = gitea_fixture(name, **replacements)
    body = JSON.generate(payload || fixture["payload"])
    env = Rack::MockRequest.env_for("/webhooks/gitea", method: "POST", input: body, "CONTENT_TYPE" => "application/json")
    fixture["headers"].merge(headers).each { |key, value| env["HTTP_#{key.upcase.tr('-', '_')}"] = value }
    env["HTTP_X_GITEA_SIGNATURE"] = OpenSSL::HMAC.hexdigest("SHA256", secret, body) if secret
    ActionDispatch::Request.new(env)
  end

  # Runs a recorded delivery through the hook handler, returning its HTTP status.
  def deliver_gitea(name, user:, payload: nil, **replacements)
    request = gitea_request(name, payload:, **replacements)
    params = ActionController::Parameters.new(payload: JSON.parse(request.raw_post))
    OpenProject::GiteaIntegration::HookHandler.new.process(request, params, user)
  end
end

RSpec.configure do |config|
  config.include GiteaWebhooks
end
