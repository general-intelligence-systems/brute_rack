#!/usr/bin/env falcon-host
# frozen_string_literal: true

# Default Brute agent service — all tools, default settings.
#
#   falcon host service.rb
#   exe/brute-server

require "brute_rack"
require "falcon/environment/server"

service "brute" do
  include Falcon::Environment::Server

  url "http://0.0.0.0:#{ENV.fetch("PORT", 9292)}"

  middleware do
    app = BruteRack::App.new(
      cwd: ENV.fetch("BRUTE_CWD", Dir.pwd),
      agent_options: { tools: Brute::TOOLS },
    )
    Falcon::Server.middleware(app)
  end
end
