# frozen_string_literal: true

module GiteaIntegration
  class LabelsComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    COLOR = /\A#\h{3}(\h{3})?\z/

    alias_method :labels, :model

    def render? = labels.present?

    def call
      flex_layout(flex_wrap: :wrap) do |row|
        labels.each do |label|
          row.with_column(mr: 1, mb: 1) do
            color = label["color"].to_s.match?(COLOR) ? label["color"] : "#59636E"
            render(Primer::Beta::Label.new(style: "color: #{color}; border-color: #{color}")) { label["name"] }
          end
        end
      end
    end
  end
end
