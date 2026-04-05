# frozen_string_literal: true

require "brute"
require "json"
require "rack"

module BruteRack
  VERSION = "0.1.2"

  # Not frozen — WEBrick mutates response headers.
  HEADERS_JSON = {"content-type" => "application/json"}

  module Endpoints
    HEADERS_JSON = BruteRack::HEADERS_JSON
  end
end

# Infrastructure
require_relative "brute_rack/sse"
require_relative "brute_rack/event_bus"
require_relative "brute_rack/session_registry"

# Endpoints (OpenCode-compatible API)
require_relative "brute_rack/endpoints/global"
require_relative "brute_rack/endpoints/sessions"
require_relative "brute_rack/endpoints/messages"
require_relative "brute_rack/endpoints/files"
require_relative "brute_rack/endpoints/tools"
require_relative "brute_rack/endpoints/config"
require_relative "brute_rack/endpoints/provider"
require_relative "brute_rack/endpoints/path_vcs"
require_relative "brute_rack/endpoints/logging"
require_relative "brute_rack/endpoints/flow"

# Rack app (router)
require_relative "brute_rack/app"
