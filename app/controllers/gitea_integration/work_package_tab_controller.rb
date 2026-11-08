# frozen_string_literal: true

module GiteaIntegration
  class WorkPackageTabController < ApplicationController
    include OpTurbo::ComponentStream

    load_and_authorize_with_permission_in_project :show_gitea_content
    before_action :find_work_package

    def tab
      component = WorkPackageTabComponent.new(@work_package)
      replace_via_turbo_stream(component:)

      respond_to_with_turbo_streams do |format|
        format.html { render(component, layout: false) }
      end
    end

    # Polled by the tab: answers 204 while nothing changed since the rendered `reference`.
    def refresh
      items = LinkedItems.new(@work_package)
      return head(:no_content) if params[:reference] == items.digest

      # The poller fetches without an Accept header and always expects a Turbo Stream.
      update_via_turbo_stream(component: WorkPackageTabComponent.new(@work_package, items:))
      render turbo_stream: resolve_turbo_streams
    end

    def count
      render json: { count: LinkedItems.new(@work_package).count }
    end

    def git_snippets_dialog
      respond_with_dialog(GitSnippetsDialogComponent.new(@work_package))
    end

    private

    def find_work_package
      @work_package = @project.work_packages.visible.find(params.expect(:work_package_id))
    end
  end
end
