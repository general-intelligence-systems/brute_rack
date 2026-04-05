# frozen_string_literal: true

module BruteRack
  module Endpoints
    # GET /provider → { all: [...], default: {...}, connected: [...] }
    module Provider
      def self.list(_env, **)
        all_providers = Endpoints::Config.available_providers
        connected = all_providers.map { |p| p[:id] }
        defaults = all_providers.each_with_object({}) { |p, h| h[p[:id]] = p[:models].first }

        [200, HEADERS_JSON, [JSON.generate(all: all_providers, default: defaults, connected: connected)]]
      end
    end
  end
end
