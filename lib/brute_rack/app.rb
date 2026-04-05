# frozen_string_literal: true

module BruteRack
  # Rack application. Routes requests by method + path to endpoint modules.
  #
  # No framework — just pattern matching on two strings.
  #
  #   # config.ru
  #   require "brute_rack"
  #   run BruteRack::App.new
  #
  class App
    HEADERS_JSON = {"content-type" => "application/json"}.freeze
    NOT_FOUND = [404, HEADERS_JSON, ['{"error":"not found"}']].freeze
    METHOD_NOT_ALLOWED = [405, HEADERS_JSON, ['{"error":"method not allowed"}']].freeze

    def initialize(cwd: Dir.pwd)
      @cwd = cwd
    end

    def call(env)
      method = env["REQUEST_METHOD"]
      path   = env["PATH_INFO"]

      case method
      when "GET"
        route_get(path, env)
      when "POST"
        route_post(path, env)
      when "DELETE"
        route_delete(path, env)
      else
        METHOD_NOT_ALLOWED
      end
    end

    private

    def route_get(path, env)
      case path
      when "/health"
        Endpoints::Health.call(env)
      when "/sessions"
        Endpoints::Sessions.list(env)
      else
        NOT_FOUND
      end
    end

    def route_post(path, env)
      case path
      when "/prompt"
        Endpoints::Prompt.call(env, cwd: @cwd)
      when "/prompt/stream"
        Endpoints::PromptStream.call(env, cwd: @cwd)
      when "/flow"
        Endpoints::Flow.call(env, cwd: @cwd)
      else
        NOT_FOUND
      end
    end

    def route_delete(path, env)
      case path
      when %r{\A/sessions/(.+)\z}
        Endpoints::Sessions.delete(env, id: $1)
      else
        NOT_FOUND
      end
    end
  end
end
