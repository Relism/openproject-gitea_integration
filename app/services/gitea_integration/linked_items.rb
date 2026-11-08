# frozen_string_literal: true

module GiteaIntegration
  # Everything Gitea linked to one work package, loaded in the order the tab shows it.
  class LinkedItems
    OPEN_FIRST = Arel.sql("CASE state WHEN 'open' THEN 0 ELSE 1 END")

    attr_reader :work_package

    def initialize(work_package)
      @work_package = work_package
    end

    def pull_requests
      @pull_requests ||= work_package.gitea_pull_requests
                                     .includes(:gitea_user, :merged_by, :reviewed_by)
                                     .order(OPEN_FIRST, gitea_updated_at: :desc)
    end

    def issues
      @issues ||= work_package.gitea_issues.includes(:gitea_user).order(OPEN_FIRST, gitea_updated_at: :desc)
    end

    def branches
      @branches ||= work_package.gitea_branches.includes(:gitea_user).order(:repository, :name)
    end

    def commits
      @commits ||= work_package.gitea_commits.order(authored_at: :desc)
    end

    def count = unordered.sum(&:count)

    def checks_for(repository_html_url, sha)
      @checks ||= GiteaCheck.where(sha: shown_shas).order(:context).group_by { [it.repository_html_url, it.sha] }
      @checks.fetch([repository_html_url, sha], [])
    end

    def latest_run_for(branch)
      @runs ||= GiteaWorkflowRun.where(head_branch: branches.map(&:name)).order(gitea_id: :desc)
                                .group_by { [it.repository_html_url, it.head_branch] }
      @runs.fetch([branch.repository_html_url, branch.name], []).first
    end

    # Changes whenever anything shown in the tab changes; lets the tab poll cheaply.
    def digest
      Digest::SHA256.hexdigest(change_markers.map { it.try(:iso8601, 6) || it.to_s }.join("|"))
    end

    private

    def change_markers
      unordered.flat_map { [it.count, it.maximum(:updated_at)] } +
        [GiteaCheck.where(sha: shown_shas).maximum(:updated_at),
         GiteaWorkflowRun.where(head_branch: branches.map(&:name)).maximum(:updated_at)]
    end

    def unordered = [pull_requests, issues, branches, commits].map { it.unscope(:order, :includes) }

    def shown_shas
      @shown_shas ||= pull_requests.filter_map(&:head_sha) + commits.map(&:sha)
    end
  end
end
