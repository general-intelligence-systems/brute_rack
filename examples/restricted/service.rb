#!/usr/bin/env async-service
# frozen_string_literal: true

# Restricted Brute agent — read-only, no shell, no file mutations.
# Suitable for research, code review, and analysis tasks.
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

service "research" do
  include Async::Service::Managed::Environment

  def service_class = BruteService
  def host = "0.0.0.0"
  def port = 9292
  def cwd = ENV.fetch("BRUTE_CWD", Dir.pwd)

  def tools
    [Brute::Tools::FSRead, Brute::Tools::FSSearch, Brute::Tools::NetFetch, Brute::Tools::TodoRead, Brute::Tools::TodoWrite]
  end

  def reasoning
    { level: :high }
  end

  def compactor_opts
    { token_threshold: 50_000 }
  end
end
