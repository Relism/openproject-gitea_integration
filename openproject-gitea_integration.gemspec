# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "openproject-gitea_integration"
  s.version     = "1.0.0"
  s.authors     = ["Zakaria El Orche (Relism)"]
  s.summary     = "OpenProject Gitea integration"
  s.description = "Links Gitea (and Forgejo) pull requests, issues, branches, commits and Actions runs " \
                  "to OpenProject work packages."
  s.license     = "GPL-3.0-only"
  s.required_ruby_version = ">= 3.4"

  s.files = Dir["{app,config,db,frontend,lib}/**/*"] + %w[README.md CHANGELOG.md LICENSE]

  s.add_dependency "openproject-webhooks"
  s.metadata["rubygems_mfa_required"] = "true"
end
