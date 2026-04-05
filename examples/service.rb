#!/usr/bin/env async-service

# Default Brute agent service.
# Copy this file and edit the method definitions to customize.
#
#   async-service examples/service.rb
#   # or
#   exe/brute-server

require "brute_rack"

service "brute" do
  include Async::Service::Managed::Environment

  def service_class = BruteRack::Service::AgentService
  def host = "127.0.0.1"
  def port = 9292
  def cwd = Dir.pwd
  def tools = Brute::TOOLS
  def reasoning = {}
  def compactor_opts = {}
end
