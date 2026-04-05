# frozen_string_literal: true

require "brute_rack"

run BruteRack::App.new(
  cwd: ENV.fetch("BRUTE_CWD", "/srv/research"),
  agent_options: {
    tools: [Brute::Tools::FSRead, Brute::Tools::FSSearch, Brute::Tools::NetFetch, Brute::Tools::TodoRead, Brute::Tools::TodoWrite],
  },
)
