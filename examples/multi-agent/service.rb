#!/usr/bin/env falcon-host
# frozen_string_literal: true

# Two Brute agents on different ports with different capabilities.
#
#   falcon host service.rb
#   exe/brute-server examples/multi-agent/service.rb

require "brute_rack"
require "falcon/environment/server"

service "reader" do
  include Falcon::Environment::Server

  url "http://0.0.0.0:9292"

  middleware do
    app = BruteRack::App.new(
      cwd: ENV.fetch("BRUTE_READER_CWD", "/srv/docs"),
      agent_options: { tools: [Brute::Tools::FSRead, Brute::Tools::FSSearch] },
    )
    Falcon::Server.middleware(app)
  end
end

service "coder" do
  include Falcon::Environment::Server

  url "http://0.0.0.0:9293"

  middleware do
    app = BruteRack::App.new(
      cwd: ENV.fetch("BRUTE_CODER_CWD", "/srv/project"),
      agent_options: { tools: Brute::TOOLS, reasoning: { level: :high } },
    )
    Falcon::Server.middleware(app)
  end
end
