# frozen_string_literal: true

module GiteaIntegration
  # Normalizes values that Gitea encodes inconsistently across webhook payloads.
  module Payload
    module_function

    # Gitea sends Go's zero time ("0001-01-01T00:00:00Z") for unset timestamps.
    def time(value)
      parsed = value.presence && Time.zone.parse(value.to_s)
      parsed if parsed && parsed.year > 1
    end

    def labels(list)
      Array(list).map { { "name" => it["name"], "color" => "##{it['color'].to_s.delete_prefix('#')}" } }
    end
  end
end
