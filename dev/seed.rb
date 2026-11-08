# frozen_string_literal: true

# Seeds OpenProject for the demo stack (run by `bin/dev up` via `rails runner` inside the openproject
# container): a "Webshop" project with three work packages, a Gitea bot user whose API token the
# webhook uses, and the plugin settings. Writes what dev/play.rb needs to play the story in Gitea to
# HANDOFF; does nothing if the project already exists.
HANDOFF = ARGV.fetch(0, "/tmp/opgitea-seed.json")
WEBHOOK_SECRET = "dev-webhook-secret"

if Project.exists?(identifier: "webshop")
  puts "OpenProject already seeded (bin/dev reset starts over)."
  FileUtils.rm_f(HANDOFF)
  exit
end

admin = User.find_by!(login: "admin")
User.current = admin

role = ProjectRole.find_or_create_by!(name: "Gitea integration") do |r|
  r.permissions = %i[view_work_packages add_work_package_comments show_gitea_content]
end

bot = User.find_by(login: "gitea") ||
      User.create!(login: "gitea", firstname: "Gitea", lastname: "Bot", mail: "gitea-bot@example.com", status: :active)

def created!(service_result)
  raise "Seeding failed: #{service_result.errors.full_messages.to_sentence}" if service_result.failure?

  service_result.result
end

project_attributes = {
  name: "Webshop", identifier: "webshop", workspace_type: "project",
  description: "Demo project connected to the Gitea repository dev/webshop.",
  enabled_module_names: %w[work_package_tracking gitea activity]
}
project = created!(Projects::CreateService.new(user: admin).call(**project_attributes))
Member.create!(project:, principal: bot, roles: [role])

def type_named(project, name)
  types = project.project_types.includes(:type).map(&:type)
  types.find { it.name == name } || types.first
end

work_packages = [
  ["Implement the checkout flow", "Feature"],
  ["Fix the login redirect", "Bug"],
  ["Update the documentation for the new checkout", "Task"]
].map do |subject, type|
  created!(WorkPackages::CreateService.new(user: admin).call(project:, subject:, type: type_named(project, type)))
end

api_token = Token::API.create!(user: bot, token_name: "Gitea webhook").plain_value
Setting.plugin_openproject_gitea_integration = { "gitea_user_id" => bot.id.to_s, "webhook_secret" => WEBHOOK_SECRET }

handoff = {
  refs: { wp1: work_packages[0].id.to_s, wp2: work_packages[1].id.to_s, wp3: work_packages[2].id.to_s,
          host: Setting.host_name },
  webhook_url: "http://openproject/webhooks/gitea?key=#{api_token}",
  webhook_secret: WEBHOOK_SECRET
}
File.write(HANDOFF, JSON.generate(handoff))
puts "Seeded project 'Webshop' with work packages #{work_packages.map(&:id).join(', ')}."
