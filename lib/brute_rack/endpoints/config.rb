# frozen_string_literal: true

module BruteRack
  module Endpoints
    # GET /config            → agent configuration
    # GET /config/providers  → available providers
    module Config
      def self.get(_env, cwd:, **)
        {
          version: Brute::VERSION,
          cwd: cwd,
          provider: ENV["LLM_PROVIDER"] || "anthropic",
          api_key_set: !ENV["LLM_API_KEY"].to_s.empty?,
          tools: LLM::Function.registry.map(&:name),
          tool_count: LLM::Function.registry.size,
          available_providers: Brute::PROVIDERS.keys,
        }.then { |config| [200, HEADERS_JSON, [JSON.generate(config)]] }
      end

      def self.providers(_env, **)
        [200, HEADERS_JSON, [JSON.generate(
          available: Brute::PROVIDERS.keys,
          current: ENV["LLM_PROVIDER"] || "anthropic",
          configured: !ENV["LLM_API_KEY"].to_s.empty?,
        )]]
      end
    end
  end
end
