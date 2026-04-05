#!/usr/bin/env falcon-host
# frozen_string_literal: true

# Two Brute agents on different ports with different capabilities.
#
#   falcon host service.rb
#   exe/brute-server examples/multi-agent/service.rb

require "brute_rack"
require "falcon/environment/rack"

service "reader" do
  include Falcon::Environment::Rack

  count 1
  port { 9292 }

  endpoint do
    Async::HTTP::Endpoint
      .parse("http://0.0.0.0:#{port}")
      .with(protocol: Async::HTTP::Protocol::HTTP1)
  end

  def cwd = ENV.fetch("BRUTE_READER_CWD", "/srv/docs")
  def tools = [Brute::Tools::FSRead, Brute::Tools::FSSearch]
  def reasoning = {}
  def compactor_opts = {}

  def rack_app
    BruteRack::App.new(
      cwd: cwd,
      agent_options: { tools: tools, reasoning: reasoning, compactor_opts: compactor_opts },
    )
  end
end

service "coder" do
  include Falcon::Environment::Rack

  count 1
  port { 9293 }

  endpoint do
    Async::HTTP::Endpoint
      .parse("http://0.0.0.0:#{port}")
      .with(protocol: Async::HTTP::Protocol::HTTP1)
  end

  def cwd = ENV.fetch("BRUTE_CODER_CWD", "/srv/project")
  def tools = Brute::TOOLS
  def reasoning = { level: :high }
  def compactor_opts = {}

  def rack_app
    BruteRack::App.new(
      cwd: cwd,
      agent_options: { tools: tools, reasoning: reasoning, compactor_opts: compactor_opts },
    )
  end
end
