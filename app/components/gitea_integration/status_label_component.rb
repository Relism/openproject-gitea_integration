# frozen_string_literal: true

module GiteaIntegration
  class StatusLabelComponent < ApplicationComponent
    def initialize(status:, text:, **system_arguments)
      super(nil)
      @status = status
      @text = text
      @system_arguments = system_arguments
    end

    def call
      render(Primer::Beta::Label.new(classes: @status.css_class, title: @text, **@system_arguments)) do
        safe_join([render(Primer::Beta::Octicon.new(icon: @status.icon, size: :xsmall, mr: 1)), @text])
      end
    end
  end
end
