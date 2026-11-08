# frozen_string_literal: true

# Minimal Gitea REST client (stdlib only) used by the dev seed and the fixture recorder.
require "base64"
require "json"
require "net/http"
require "uri"

class Gitea
  class Error < StandardError; end

  def initialize(url:, token: nil, user: nil, password: nil)
    @base = URI(url)
    @token = token
    @basic = [user, password] if user
  end

  def get(path, **) = request(Net::HTTP::Get, path, **)
  def post(path, body = {}, **) = request(Net::HTTP::Post, path, body, **)
  def put(path, body = {}, **) = request(Net::HTTP::Put, path, body, **)
  def patch(path, body = {}, **) = request(Net::HTTP::Patch, path, body, **)
  def delete(path, **) = request(Net::HTTP::Delete, path, **)

  # Blocks until Gitea answers its health check.
  def wait_until_healthy(timeout: 120)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until healthy?
      raise Error, "Gitea at #{@base} did not become healthy" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 1
    end
  end

  def healthy?
    Net::HTTP.get_response(URI.join(@base, "/api/healthz")).is_a?(Net::HTTPSuccess)
  rescue SystemCallError, IOError
    false
  end

  # Creates a file in a single commit, optionally on a new branch forked from `branch`.
  def create_file(repo, path, content:, message:, branch: "main", new_branch: nil, sudo: nil)
    post("/repos/#{repo}/contents/#{path}",
         { content: Base64.strict_encode64(content), message:, branch:, new_branch: }.compact,
         sudo:)
  end

  def update_file(repo, path, content:, message:, branch:)
    sha = get("/repos/#{repo}/contents/#{path}?ref=#{URI.encode_www_form_component(branch)}").fetch("sha")
    put("/repos/#{repo}/contents/#{path}",
        { content: Base64.strict_encode64(content), message:, branch:, sha: })
  end

  private

  def request(klass, path, body = nil, sudo: nil, allow: [])
    req = build_request(klass, URI.join(@base, "/api/v1#{path}"), body, sudo)
    res = Net::HTTP.start(req.uri.host, req.uri.port) { |http| http.request(req) }
    return if allow.include?(res.code.to_i)

    parse(res, "#{klass::METHOD} #{path}")
  end

  def parse(res, description)
    raise Error, "#{description} → #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body) unless res.body.to_s.empty?
  end

  def build_request(klass, uri, body, sudo)
    klass.new(uri, "Content-Type" => "application/json", "Accept" => "application/json").tap do |req|
      if @token
        req["Authorization"] = "token #{@token}"
      else
        req.basic_auth(*@basic)
      end
      req["Sudo"] = sudo if sudo
      req.body = JSON.generate(body) if body
    end
  end
end
