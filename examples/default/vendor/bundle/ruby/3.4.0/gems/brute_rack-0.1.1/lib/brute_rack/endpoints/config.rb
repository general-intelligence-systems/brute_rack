# frozen_string_literal: true

module BruteRack
  module Endpoints
    # GET /config            → agent configuration
    # GET /config/providers  → available providers and models
    module Config
      PROVIDER_MAP = {
        "ANTHROPIC_API_KEY" => { id: "anthropic", name: "Anthropic", models: ["claude-sonnet-4-20250514", "claude-haiku-4-20250414"] },
        "OPENAI_API_KEY"    => { id: "openai",    name: "OpenAI",    models: ["gpt-4o", "gpt-4o-mini", "o3-mini"] },
        "GOOGLE_API_KEY"    => { id: "google",    name: "Google",    models: ["gemini-2.0-flash", "gemini-2.5-pro"] },
      }.freeze

      def self.get(_env, cwd:, **)
        {
          version: Brute::VERSION,
          cwd: cwd,
          tools: LLM::Function.registry.map(&:name),
          tool_count: LLM::Function.registry.size,
          providers: available_providers.map { |p| p[:id] },
        }.then { |config| [200, HEADERS_JSON, [JSON.generate(config)]] }
      end

      def self.providers(_env, **)
        providers = available_providers
        defaults = providers.each_with_object({}) { |p, h| h[p[:id]] = p[:models].first }
        [200, HEADERS_JSON, [JSON.generate(providers: providers, default: defaults)]]
      end

      def self.available_providers
        PROVIDER_MAP.filter_map do |env_key, info|
          info if ENV[env_key]
        end
      end
    end
  end
end
