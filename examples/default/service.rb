#!/usr/bin/env falcon-host
# frozen_string_literal: true

# Default Brute agent service — all tools, default settings.
#
#   falcon host service.rb
#   exe/brute-server

require "brute_rack"
require "falcon"

service "brute" do
  include Async::Service::Managed::Environment

  service_class Falcon::Service::Server
  port ENV.fetch("PORT", 9292).to_i

  endpoint do
    Async::HTTP::Endpoint.parse("http://0.0.0.0:#{port}")
  end

  make_server do
    app = BruteRack::App.new(
      cwd: ENV.fetch("BRUTE_CWD", Dir.pwd),
      agent_options: { tools: Brute::TOOLS },
    )
    Falcon::Server.new(Falcon::Server.middleware(app), endpoint)
  end
end
