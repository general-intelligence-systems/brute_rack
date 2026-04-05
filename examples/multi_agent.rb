#!/usr/bin/env async-service

# Two agents on different ports with different capabilities.
#
#   async-service examples/multi_agent.rb

require "brute_rack"

service "reader" do
  include Async::Service::Managed::Environment

  def service_class = BruteRack::Service::AgentService
  def host = "127.0.0.1"
  def port = 9292
  def cwd = "/srv/docs"
  def tools = [Brute::Tools::FSRead, Brute::Tools::FSSearch]
  def reasoning = {}
  def compactor_opts = {}
end

service "coder" do
  include Async::Service::Managed::Environment

  def service_class = BruteRack::Service::AgentService
  def host = "127.0.0.1"
  def port = 9293
  def cwd = "/srv/project"
  def tools = Brute::TOOLS
  def reasoning = { level: :high }
  def compactor_opts = {}
end
