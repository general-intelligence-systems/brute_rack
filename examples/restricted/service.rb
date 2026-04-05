#!/usr/bin/env falcon-host
# frozen_string_literal: true

# Restricted Brute agent — read-only, no shell, no file mutations.
#
#   falcon host service.rb
#   exe/brute-server examples/restricted/service.rb

require "brute_rack"
require "falcon/environment/rack"

service "research" do
  include Falcon::Environment::Rack

  count 1
  port { ENV.fetch("PORT", 9292).to_i }

  endpoint do
    Async::HTTP::Endpoint
      .parse("http://0.0.0.0:#{port}")
      .with(protocol: Async::HTTP::Protocol::HTTP1)
  end

  def cwd = ENV.fetch("BRUTE_CWD", "/srv/research")

  def tools
    [Brute::Tools::FSRead, Brute::Tools::FSSearch, Brute::Tools::NetFetch, Brute::Tools::TodoRead, Brute::Tools::TodoWrite]
  end

  def reasoning = { level: :high }
  def compactor_opts = { token_threshold: 50_000 }

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
