#!/usr/bin/env async-service

# Default Brute agent service.
# Copy this file and edit to customize.
#
#   async-service examples/service.rb
#   exe/brute-server
#   exe/brute-server examples/service.rb

require "brute_rack"
require "falcon"

class BruteService < Async::Service::Managed::Service
  private def format_title(evaluator, server)
    "#{self.name} [#{evaluator.host}:#{evaluator.port}]"
  end

  def run(instance, evaluator)
    app = BruteRack::App.new(
      cwd: evaluator.cwd,
      agent_options: {
        tools: evaluator.tools,
        reasoning: evaluator.reasoning,
        compactor_opts: evaluator.compactor_opts,
      },
    )

    endpoint = Async::HTTP::Endpoint.parse("http://#{evaluator.host}:#{evaluator.port}")
    Falcon::Server.new(Falcon::Server.middleware(app), endpoint).run
  end
end

service "brute" do
  include Async::Service::Managed::Environment

  def service_class = BruteService
  def host = "127.0.0.1"
  def port = 9292
  def cwd = Dir.pwd
  def tools = Brute::TOOLS
  def reasoning = {}
  def compactor_opts = {}
end
