#!/usr/bin/env async-service

# Two agents on different ports with different capabilities.
#
#   async-service examples/multi_agent.rb
#   exe/brute-server examples/multi_agent.rb

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

service "reader" do
  include Async::Service::Managed::Environment

  def service_class = BruteService
  def host = "127.0.0.1"
  def port = 9292
  def cwd = "/srv/docs"
  def tools = [Brute::Tools::FSRead, Brute::Tools::FSSearch]
  def reasoning = {}
  def compactor_opts = {}
end

service "coder" do
  include Async::Service::Managed::Environment

  def service_class = BruteService
  def host = "127.0.0.1"
  def port = 9293
  def cwd = "/srv/project"
  def tools = Brute::TOOLS
  def reasoning = { level: :high }
  def compactor_opts = {}
end
