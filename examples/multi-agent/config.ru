# frozen_string_literal: true

require "brute_rack"

run BruteRack::App.new(
  cwd: ENV.fetch("BRUTE_CWD", Dir.pwd),
  agent_options: {
    tools: Brute::TOOLS,
  },
)
