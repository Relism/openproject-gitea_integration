# frozen_string_literal: true

module GiteaIntegration
  # Display state of a Gitea item: color (registered as `__hl_gitea_<group>_status_<code>` classes) and octicon.
  Status = Data.define(:group, :code, :hexcode, :icon) do
    def id = code

    def color = ::Color.new(hexcode:)

    def css_class = "__hl_background_muted #{color_class}"

    def icon_class = "__hl_foreground #{color_class}"

    def color_class = "__hl_gitea_#{group}_status_#{code}"
  end

  class Status
    GREEN = "#1A7F37"
    RED = "#CF222E"
    PURPLE = "#8250DF"
    GRAY = "#59636E"
    YELLOW = "#9A6700"
    BLUE = "#0969DA"

    def self.define(group, statuses)
      statuses.to_h { |code, (hexcode, icon)| [code, new(group:, code:, hexcode:, icon:)] }.freeze
    end

    GROUPS = {
      pull_request: define(:pull_request, "open" => [GREEN, :"git-pull-request"],
                                          "draft" => [GRAY, :"git-pull-request-draft"],
                                          "merged" => [PURPLE, :"git-merge"],
                                          "closed" => [RED, :"git-pull-request-closed"]),
      issue: define(:issue, "open" => [GREEN, :"issue-opened"], "closed" => [PURPLE, :"issue-closed"]),
      review: define(:review, "approved" => [GREEN, :check], "changes_requested" => [RED, :"file-diff"]),
      check: define(:check, "success" => [GREEN, :"check-circle"], "failure" => [RED, :"x-circle"],
                            "error" => [RED, :alert], "warning" => [YELLOW, :alert],
                            "pending" => [YELLOW, :"dot-fill"], "skipped" => [GRAY, :skip],
                            "cancelled" => [GRAY, :stop], "queued" => [YELLOW, :clock],
                            "waiting" => [YELLOW, :clock], "requested" => [YELLOW, :clock],
                            "in_progress" => [BLUE, :sync])
    }.freeze

    def self.for(group, code)
      GROUPS.fetch(group).fetch(code.to_s) { new(group:, code: code.to_s, hexcode: GRAY, icon: :question) }
    end
  end
end
