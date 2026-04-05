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

  def service_class = Falcon::Service::Server
  def port = ENV.fetch("PORT", 9292).to_i
  def cwd = ENV.fetch("BRUTE_CWD", Dir.pwd)
  def tools = Brute::TOOLS
  def reasoning = {}
  def compactor_opts = {}

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
