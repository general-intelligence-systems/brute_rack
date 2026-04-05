# frozen_string_literal: true

require "brute"
require "json"

module BruteRack
  VERSION = "0.1.0"

  module Endpoints; end

  def self.config_ru_path
    File.expand_path("../config.ru", __dir__)
  end
end

require_relative "brute_rack/sse"
require_relative "brute_rack/endpoints/health"
require_relative "brute_rack/endpoints/prompt"
require_relative "brute_rack/endpoints/prompt_stream"
require_relative "brute_rack/endpoints/sessions"
require_relative "brute_rack/endpoints/flow"
require_relative "brute_rack/app"
