#!/usr/bin/env async-service

# Read-only research agent — no writes, no shell, no deletions.
#
#   async-service examples/restricted.rb
#   exe/brute-server examples/restricted.rb

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

service "research" do
  include Async::Service::Managed::Environment

  def service_class = BruteService
  def host = "127.0.0.1"
  def port = 9292
  def cwd = "/srv/research"
  def tools = [Brute::Tools::FSRead, Brute::Tools::FSSearch, Brute::Tools::NetFetch]
  def reasoning = { level: :high }
  def compactor_opts = { token_threshold: 50_000 }
end
