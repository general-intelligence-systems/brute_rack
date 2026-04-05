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

  def service_class = Falcon::Service::Server
  def port = ENV.fetch("PORT", 9292).to_i
  def cwd = ENV.fetch("BRUTE_CWD", "/srv/research")
  def tools = [Brute::Tools::FSRead, Brute::Tools::FSSearch, Brute::Tools::NetFetch, Brute::Tools::TodoRead, Brute::Tools::TodoWrite]
  def reasoning = { level: :high }
  def compactor_opts = { token_threshold: 50_000 }

  def endpoint
    Async::HTTP::Endpoint.parse("http://0.0.0.0:#{port}")
  end

  def make_server
    app = BruteRack::App.new(
      cwd: cwd,
      agent_options: { tools: tools, reasoning: reasoning, compactor_opts: compactor_opts },
    )
    Falcon::Server.new(Falcon::Server.middleware(app), endpoint)
  end
end
