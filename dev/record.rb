# frozen_string_literal: true

# Records real Gitea webhook deliveries as spec fixtures (run via `bin/dev record`).
#
# Plays dev/scenario.rb against the dev Gitea with this container as the webhook target and
# writes each delivery to spec/fixtures/gitea_webhooks/<event>/<name>.json as
# { "headers": {...}, "payload": {...} }. Work package references stay as ${wp1}-style
# placeholders that the spec helper substitutes.
require "fileutils"
require "json"
require "socket"
require_relative "gitea"
require_relative "scenario"

FIXTURES = ENV.fetch("FIXTURES_DIR") { File.expand_path("../spec/fixtures/gitea_webhooks", __dir__) }
KEPT_HEADERS = %w[X-Gitea-Event X-Gitea-Event-Type X-Gitea-Delivery X-Gitea-Hook-Installation-Target-Type].freeze

deliveries = Queue.new
server = TCPServer.new("0.0.0.0", 9999)
Thread.new do
  loop do
    client = server.accept
    request_line = client.gets
    headers = {}
    while (line = client.gets) && line != "\r\n"
      key, value = line.split(":", 2)
      headers[key.strip.downcase] = value.strip
    end
    body = client.read(headers.fetch("content-length", "0").to_i)
    client.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
    client.close
    kept = KEPT_HEADERS.filter_map { |name| [name, headers[name.downcase]] if headers[name.downcase] }.to_h
    deliveries << { headers: kept, body: } if request_line
  rescue StandardError => e
    warn "capture failed: #{e.message}"
  end
end

# Waits until no delivery arrived for `quiet` seconds.
def drain(queue, quiet: 3)
  received = []
  loop do
    received << queue.pop(timeout: quiet)
    break if received.last.nil?
  end
  received.compact
end

# Story steps name their deliveries; CI deliveries are named by outcome and the last one wins,
# which keeps a single fixture per status transition instead of one per job and run.
def name_for(label, headers, payload)
  event, type = headers.values_at("X-Gitea-Event", "X-Gitea-Event-Type")
  case event
  when "workflow_run", "workflow_job"
    [payload["action"], payload.dig(event, "conclusion")].compact.join("_")
  when "status"
    "#{payload['context'].downcase.gsub(/[^a-z0-9]+/, '_').delete_suffix('_')}_#{payload['state']}"
  else
    [event, label.to_s].include?(type) ? label.to_s : "#{label}.#{type}"
  end
end

def ci_event?(headers) = %w[workflow_run workflow_job status].include?(headers["X-Gitea-Event"])

gitea = Gitea.new(url: ENV.fetch("GITEA_URL"), user: "dev", password: "devdevdev")
gitea.wait_until_healthy
token = gitea.post("/users/dev/tokens", { name: "recorder-#{Time.now.to_i}", scopes: ["all"] }).fetch("sha1")
gitea = Gitea.new(url: ENV.fetch("GITEA_URL"), token:)

FileUtils.rm_rf(FIXTURES)
written = Hash.new(0)
store = lambda do |label|
  drain(deliveries).each do |delivery|
    headers = delivery[:headers]
    payload = JSON.parse(delivery[:body])
    name = name_for(label, headers, payload)
    key = "#{headers['X-Gitea-Event']}/#{name}"
    written[key] += 1
    key = "#{key}_#{written[key]}" if written[key] > 1 && !ci_event?(headers)
    path = File.join(FIXTURES, "#{key}.json")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#{JSON.pretty_generate(headers:, payload:)}\n")
    puts "  #{headers['X-Gitea-Event-Type'].to_s.ljust(30)} → #{key}.json"
  end
end

refs = { wp1: "${wp1}", wp2: "${wp2}", wp3: "${wp3}", host: "${host}" }
scenario = Scenario.new(gitea, refs:, repo: "dev/webshop", step: lambda { |label, &blk|
  puts "▸ #{label}"
  result = blk.call
  store.call(label)
  result
})
scenario.prepare!(webhook_url: "http://opgitea-recorder:9999/", webhook_secret: "fixture-secret")
scenario.play!
store.call(:late)
puts "Recorded #{written.values.sum} deliveries as #{Dir[File.join(FIXTURES, '**/*.json')].size} fixtures"
