# frozen_string_literal: true

module GiteaIntegration
  class IssueComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    alias_method :issue, :model
  end
end
