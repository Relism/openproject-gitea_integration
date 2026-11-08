# frozen_string_literal: true

module GiteaIntegration
  module Admin
    class SettingsForm < ApplicationForm
      form do |f|
        f.autocompleter(
          name: :gitea_user_id,
          label: I18n.t("gitea_integration.settings.actor"),
          caption: I18n.t("gitea_integration.settings.actor_caption"),
          autocomplete_options: {
            component: "opce-user-autocompleter",
            allowEmpty: true,
            defaultData: false,
            model: @actor && { id: @actor.id, name: @actor.name }
          }
        )

        f.text_field(
          name: :webhook_secret,
          label: I18n.t("gitea_integration.settings.webhook_secret"),
          caption: I18n.t("gitea_integration.settings.webhook_secret_caption"),
          value: @webhook_secret,
          input_width: :xlarge
        )

        f.submit(name: :submit, label: I18n.t(:button_save), scheme: :primary)
      end

      def initialize(actor: nil, webhook_secret: nil)
        super()
        @actor = actor
        @webhook_secret = webhook_secret
      end
    end
  end
end
