# frozen_string_literal: true

require "logger"

module BruteRack
  # Rack application implementing the OpenCode-compatible server API.
  # Routes requests by method + path to endpoint modules.
  #
  #   # config.ru
  #   require "brute_rack"
  #   run BruteRack::App.new
  #
  class App
    def self.not_found
      [404, {"content-type" => "application/json"}, ['{"error":"not found"}']]
    end

    def self.method_not_allowed
      [405, {"content-type" => "application/json"}, ['{"error":"method not allowed"}']]
    end

    def initialize(cwd: Dir.pwd)
      @cwd = cwd
      @logger = Logger.new($stderr, level: Logger::INFO)
      @event_bus = EventBus.new
      @registry = SessionRegistry.new(event_bus: @event_bus, cwd: cwd)
    end

    def call(env)
      method = env["REQUEST_METHOD"]
      path   = env["PATH_INFO"]

      case method
      when "GET"    then route_get(path, env)
      when "POST"   then route_post(path, env)
      when "PATCH"  then route_patch(path, env)
      when "DELETE" then route_delete(path, env)
      else self.class.method_not_allowed
      end
    end

    private

    def ctx
      { cwd: @cwd, event_bus: @event_bus, registry: @registry, logger: @logger }
    end

    # ----------------------------------------------------------------
    # GET
    # ----------------------------------------------------------------
    def route_get(path, env)
      case path
      # Global
      when "/global/health"             then Endpoints::Global.health(env, **ctx)
      when "/global/event"              then Endpoints::Global.event(env, **ctx)
      when "/event"                     then Endpoints::Global.event(env, **ctx)
      # Sessions
      when "/session"                   then Endpoints::Sessions.list(env, **ctx)
      when "/session/status"            then Endpoints::Sessions.status(env, **ctx)
      when %r{\A/session/([^/]+)/message/(.+)\z}
        Endpoints::Messages.get_message(env, id: $1, message_id: $2, **ctx)
      when %r{\A/session/([^/]+)/message\z}
        Endpoints::Messages.list(env, id: $1, **ctx)
      when %r{\A/session/([^/]+)/todo\z}
        Endpoints::Sessions.todo(env, id: $1, **ctx)
      when %r{\A/session/([^/]+)\z}
        Endpoints::Sessions.get(env, id: $1, **ctx)
      # Files
      when "/find"                      then Endpoints::Files.find(env, **ctx)
      when "/find/file"                 then Endpoints::Files.find_file(env, **ctx)
      when "/file/content"              then Endpoints::Files.content(env, **ctx)
      when "/file/status"               then Endpoints::Files.status(env, **ctx)
      when "/file"                      then Endpoints::Files.list(env, **ctx)
      # Tools
      when "/experimental/tool/ids"     then Endpoints::Tools.ids(env, **ctx)
      when "/experimental/tool"         then Endpoints::Tools.list(env, **ctx)
      # Config & Provider
      when "/config/providers"          then Endpoints::Config.providers(env, **ctx)
      when "/config"                    then Endpoints::Config.get(env, **ctx)
      when "/provider"                  then Endpoints::Provider.list(env, **ctx)
      # Path & VCS
      when "/path"                      then Endpoints::PathVcs.path(env, **ctx)
      when "/vcs"                       then Endpoints::PathVcs.vcs(env, **ctx)
      else self.class.not_found
      end
    end

    # ----------------------------------------------------------------
    # POST
    # ----------------------------------------------------------------
    def route_post(path, env)
      case path
      # Sessions
      when "/session"
        Endpoints::Sessions.create(env, **ctx)
      when %r{\A/session/([^/]+)/message\z}
        Endpoints::Messages.send_message(env, id: $1, **ctx)
      when %r{\A/session/([^/]+)/prompt_async\z}
        Endpoints::Messages.prompt_async(env, id: $1, **ctx)
      when %r{\A/session/([^/]+)/shell\z}
        Endpoints::Messages.shell(env, id: $1, **ctx)
      when %r{\A/session/([^/]+)/abort\z}
        Endpoints::Sessions.abort(env, id: $1, **ctx)
      when %r{\A/session/([^/]+)/fork\z}
        Endpoints::Sessions.fork(env, id: $1, **ctx)
      when %r{\A/session/([^/]+)/summarize\z}
        Endpoints::Sessions.summarize(env, id: $1, **ctx)
      # Flow (brute-specific)
      when "/flow"
        Endpoints::Flow.call(env, **ctx)
      # Logging
      when "/log"
        Endpoints::Logging.create(env, **ctx)
      else self.class.not_found
      end
    end

    # ----------------------------------------------------------------
    # PATCH
    # ----------------------------------------------------------------
    def route_patch(path, env)
      case path
      when %r{\A/session/([^/]+)\z}
        Endpoints::Sessions.update(env, id: $1, **ctx)
      else self.class.not_found
      end
    end

    # ----------------------------------------------------------------
    # DELETE
    # ----------------------------------------------------------------
    def route_delete(path, env)
      case path
      when %r{\A/session/([^/]+)\z}
        Endpoints::Sessions.delete(env, id: $1, **ctx)
      else self.class.not_found
      end
    end
  end
end
