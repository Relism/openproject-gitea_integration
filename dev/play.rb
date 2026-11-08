# frozen_string_literal: true

# Drives the demo Gitea (plain Ruby, run in the `tools` container by bin/dev):
#   play.rb story < handoff.json   plays dev/scenario.rb with the work packages dev/seed.rb created
#   play.rb push MESSAGE           pushes one commit with MESSAGE to dev/webshop (used by bin/dev e2e)
require "json"
require "securerandom"
require_relative "gitea"
require_relative "scenario"

GITEA_URL = ENV.fetch("GITEA_URL", "http://gitea:3000")
$stdout.sync = true

gitea = Gitea.new(url: GITEA_URL, user: "dev", password: "devdevdev")
gitea.wait_until_healthy
token = gitea.post("/users/dev/tokens", { name: "dev-#{SecureRandom.hex(4)}", scopes: ["all"] }).fetch("sha1")
gitea = Gitea.new(url: GITEA_URL, token:)

case ARGV.first
when "story"
  handoff = JSON.parse($stdin.read, symbolize_names: true)
  narrate = lambda do |label, &blk|
    puts "  ▸ #{label}"
    blk.call
  end
  scenario = Scenario.new(gitea, refs: handoff.fetch(:refs), repo: "dev/webshop", step: narrate)
  scenario.prepare!(webhook_url: handoff.fetch(:webhook_url), webhook_secret: handoff.fetch(:webhook_secret))
  scenario.play!
when "push"
  gitea.create_file("dev/webshop", "notes/#{SecureRandom.hex(4)}.md", content: "#{ARGV[1]}\n", message: ARGV.fetch(1))
else
  abort "usage: play.rb story < handoff.json | play.rb push MESSAGE"
end
