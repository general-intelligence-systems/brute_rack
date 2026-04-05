#!/usr/bin/env async-service
# frozen_string_literal: true

# Default Brute agent service — all tools, default settings.
#
#   async-service service.rb
#   exe/brute-server

require "brute_rack"
require "async/service"
require "async/service/managed/environment"
require "async/service/managed/service"
require "async/http"
require "falcon"

class BruteService < Async::Service::Managed::Service
  def start
    super
    @endpoint = Async::HTTP::Endpoint.parse("http://#{@evaluator.host}:#{@evaluator.port}")
    @bound_endpoint = Sync { @endpoint.bound }
  end

  def stop
    @bound_endpoint&.close
    super
  end

  private def format_title(evaluator, server)
    connections = server.respond_to?(:connection_count) ? " (#{server.connection_count} conn)" : ""
    "#{self.name} [#{evaluator.host}:#{evaluator.port}]#{connections}"
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

    Async do |task|
      server = Falcon::Server.new(Falcon::Server.middleware(app), @bound_endpoint)
      server.run
      instance.ready!
      task.sleep # block forever — server runs in background fibers
    end
  end
end

container_policy Async::Service::Policy.new(maximum_failures: 5, window: 60)

service "brute" do
  include Async::Service::Managed::Environment

  def service_class = BruteService
  def host = "0.0.0.0"
  def port = 9292
  def cwd = ENV.fetch("BRUTE_CWD", Dir.pwd)
  def tools = Brute::TOOLS
  def reasoning = {}
  def compactor_opts = {}
end
