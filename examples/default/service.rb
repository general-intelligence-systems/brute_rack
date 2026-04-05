#!/usr/bin/env falcon-host
# frozen_string_literal: true

# Default Brute agent service — all tools, default settings.
#
#   falcon host service.rb
#   exe/brute-server

require "brute_rack"
require "falcon/environment/rack"

service "brute" do
  include Falcon::Environment::Rack

  count 1
  port { ENV.fetch("PORT", 9292).to_i }

  endpoint do
    Async::HTTP::Endpoint
      .parse("http://0.0.0.0:#{port}")
      .with(protocol: Async::HTTP::Protocol::HTTP1)
  end

  def cwd = ENV.fetch("BRUTE_CWD", Dir.pwd)
  def tools = Brute::TOOLS
  def reasoning = {}
  def compactor_opts = {}

  def app
    BruteRack::App.new(
      cwd: cwd,
      agent_options: {
        tools: tools,
        reasoning: reasoning,
        compactor_opts: compactor_opts,
      },
    )
  end
end
