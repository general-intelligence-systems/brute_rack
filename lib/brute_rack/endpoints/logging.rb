# frozen_string_literal: true

module BruteRack
  module Endpoints
    # POST /log → { service, level, message, extra? }
    module Logging
      LEVELS = %w[debug info warn error fatal].freeze

      def self.create(env, logger:, **)
        input = env["rack.input"].read
        body = input.empty? ? {} : JSON.parse(input)

        level = body["level"] || "info"
        level = "info" unless LEVELS.include?(level)
        message = "[#{body["service"] || "client"}] #{body["message"]}"

        logger.send(level.to_sym, message)

        [200, HEADERS_JSON, [JSON.generate(true)]]
      rescue => e
        [500, HEADERS_JSON, [JSON.generate(error: e.message)]]
      end
    end
  end
end
