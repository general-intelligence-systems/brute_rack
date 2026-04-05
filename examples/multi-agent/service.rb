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

  def service_class = Falcon::Service::Server
  def cwd = ENV.fetch("BRUTE_READER_CWD", "/srv/docs")
  def tools = [Brute::Tools::FSRead, Brute::Tools::FSSearch]
  def reasoning = {}
  def compactor_opts = {}

  def endpoint
    Async::HTTP::Endpoint.parse("http://0.0.0.0:9292")
  end

  def make_server
    app = BruteRack::App.new(
      cwd: cwd,
      agent_options: { tools: tools, reasoning: reasoning, compactor_opts: compactor_opts },
    )
    Falcon::Server.new(Falcon::Server.middleware(app), endpoint)
  end
end

service "coder" do
  include Async::Service::Managed::Environment

  def service_class = Falcon::Service::Server
  def cwd = ENV.fetch("BRUTE_CODER_CWD", "/srv/project")
  def tools = Brute::TOOLS
  def reasoning = { level: :high }
  def compactor_opts = {}

  def endpoint
    Async::HTTP::Endpoint.parse("http://0.0.0.0:9293")
  end

  def make_server
    app = BruteRack::App.new(
      cwd: cwd,
      agent_options: { tools: tools, reasoning: reasoning, compactor_opts: compactor_opts },
    )
    Falcon::Server.new(Falcon::Server.middleware(app), endpoint)
  end
end
