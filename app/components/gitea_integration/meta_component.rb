# frozen_string_literal: true

module GiteaIntegration
  # "<avatar> <text> <relative time>" footer line of a tab item.
  class MetaComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    def initialize(text:, time:, user: nil)
      super(nil)
      @text = text
      @time = time
      @user = user
    end

    def call
      flex_layout(align_items: :center, classes: "op-gitea-meta") do |row|
        if @user
          row.with_column(mr: 1) do
            render(Primer::OpenProject::AvatarWithFallback.new(src: @user.avatar_url, alt: @user.display_name, size: 16))
          end
        end
        row.with_column(mr: 1) { render(Primer::Beta::Text.new(font_size: :small, color: :muted)) { @text } }
        if @time
          row.with_column do
            render(Primer::Beta::Text.new(font_size: :small, color: :muted)) do
              render(OpPrimer::RelativeTimeComponent.new(datetime: @time, prefix: ""))
            end
          end
        end
      end
    end
  end
end
