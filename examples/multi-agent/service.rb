#!/usr/bin/env async-service
# frozen_string_literal: true

# Two Brute agents on different ports with different capabilities.
# A read-only reader on 9292 and a full-power coder on 9293.
#
#   async-service service.rb

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

    server = Falcon::Server.new(Falcon::Server.middleware(app), @bound_endpoint)
    instance.ready!
    server.run
  end
end

container_policy Async::Service::Policy.new(maximum_failures: 5, window: 60)

service "reader" do
  include Async::Service::Managed::Environment

  def service_class = BruteService
  def host = "0.0.0.0"
  def port = 9292
  def cwd = ENV.fetch("BRUTE_READER_CWD", "/srv/docs")
  def tools = [Brute::Tools::FSRead, Brute::Tools::FSSearch]
  def reasoning = {}
  def compactor_opts = {}
end

service "coder" do
  include Async::Service::Managed::Environment

  def service_class = BruteService
  def host = "0.0.0.0"
  def port = 9293
  def cwd = ENV.fetch("BRUTE_CODER_CWD", "/srv/project")
  def tools = Brute::TOOLS
  def reasoning = { level: :high }
  def compactor_opts = {}
end
