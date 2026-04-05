#!/usr/bin/env async-service

# Read-only research agent — no writes, no shell, no deletions.
#
#   async-service examples/restricted.rb

require "brute_rack"

service "research" do
  include Async::Service::Managed::Environment

  def service_class = BruteRack::Service::AgentService
  def host = "127.0.0.1"
  def port = 9292
  def cwd = "/srv/research"

  def tools
    [Brute::Tools::FSRead, Brute::Tools::FSSearch, Brute::Tools::NetFetch]
  end

  def reasoning
    { level: :high }
  end

  def compactor_opts
    { token_threshold: 50_000 }
  end
end
