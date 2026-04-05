#!/usr/bin/env falcon-host
# frozen_string_literal: true

# Restricted Brute agent — read-only, no shell, no file mutations.
#
#   falcon host service.rb
#   exe/brute-server examples/restricted/service.rb

require "brute_rack"
require "falcon"

service "research" do
  include Async::Service::Managed::Environment

  service_class Falcon::Service::Server
  port ENV.fetch("PORT", 9292).to_i

  endpoint do
    Async::HTTP::Endpoint.parse("http://0.0.0.0:#{port}")
  end

  make_server do
    tools = [Brute::Tools::FSRead, Brute::Tools::FSSearch, Brute::Tools::NetFetch, Brute::Tools::TodoRead, Brute::Tools::TodoWrite]
    app = BruteRack::App.new(
      cwd: ENV.fetch("BRUTE_CWD", "/srv/research"),
      agent_options: { tools: tools, reasoning: { level: :high }, compactor_opts: { token_threshold: 50_000 } },
    )
    Falcon::Server.new(Falcon::Server.middleware(app), endpoint)
  end
end
