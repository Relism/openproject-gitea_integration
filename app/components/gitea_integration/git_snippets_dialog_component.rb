# frozen_string_literal: true

module GiteaIntegration
  class GitSnippetsDialogComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers
    include OpTurbo::Streamable

    alias_method :work_package, :model

    def branch_prefix
      "#{slug(work_package.type.name)}/#{work_package.display_id.to_s.downcase}"
    end

    def branch_name = "#{branch_prefix}-#{slug(work_package.subject)}"

    def commit_message_lines
      ["OP##{work_package.display_id} #{work_package.subject}", url_helpers.work_package_short_url(work_package)]
    end

    def commit_message = commit_message_lines.join("\n\n")

    def create_branch_command
      messages = commit_message_lines.map { "-m #{Shellwords.escape(it)}" }
      ["git switch -c #{Shellwords.escape(branch_name)}", "git commit --allow-empty #{messages.join(' ')}"].join(" && ")
    end

    private

    def slug(text)
      text.to_s.gsub("&", " and ").gsub(/\W+/, "-").delete_prefix("-").delete_suffix("-").downcase
    end
  end
end
