#!/usr/bin/env falcon-host
# frozen_string_literal: true

# Two Brute agents on different ports with different capabilities.
#
#   falcon host service.rb
#   exe/brute-server examples/multi-agent/service.rb

require "brute_rack"
require "falcon"

service "reader" do
  include Async::Service::Managed::Environment

  service_class Falcon::Service::Server

  endpoint do
    Async::HTTP::Endpoint.parse("http://0.0.0.0:9292")
  end

  make_server do
    app = BruteRack::App.new(
      cwd: ENV.fetch("BRUTE_READER_CWD", "/srv/docs"),
      agent_options: { tools: [Brute::Tools::FSRead, Brute::Tools::FSSearch] },
    )
    Falcon::Server.new(Falcon::Server.middleware(app), endpoint)
  end
end

service "coder" do
  include Async::Service::Managed::Environment

  service_class Falcon::Service::Server

  endpoint do
    Async::HTTP::Endpoint.parse("http://0.0.0.0:9293")
  end

  make_server do
    app = BruteRack::App.new(
      cwd: ENV.fetch("BRUTE_CODER_CWD", "/srv/project"),
      agent_options: { tools: Brute::TOOLS, reasoning: { level: :high } },
    )
    Falcon::Server.new(Falcon::Server.middleware(app), endpoint)
  end
end
