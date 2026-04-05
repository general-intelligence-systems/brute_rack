# frozen_string_literal: true

module BruteRack
  module Endpoints
    # POST /flow — run a BPMN multi-agent flow.
    #
    # Request:  { "message": "...", "cwd": "..." }
    # Response: { "result": {...} }
    #
    # Requires the brute_flow gem to be installed.
    #
    module Flow
      def self.call(env, cwd:)
        require "brute_flow"

        JSON.parse(env["rack.input"].read).then do |body|
          Brute.flow(cwd: body["cwd"] || cwd, variables: { user_message: body["message"] }) do
            service :router, type: "Brute::Flow::Services::RouterService"
            exclusive_gateway :mode, default: :simple_path do
              branch :fibre_path, condition: '=agent_mode = "fibre"' do
                parallel do
                  service :tools,  type: "Brute::Flow::Services::ToolSuggestService"
                  service :memory, type: "Brute::Flow::Services::MemoryRecallService"
                end
                service :agent, type: "Brute::Flow::Services::AgentService"
              end
              branch :simple_path do
                service :agent, type: "Brute::Flow::Services::AgentService"
              end
            end
          end.then do |runner|
            runner.run.then do |result|
              [200, {"content-type" => "application/json"}, [JSON.generate(result: result)]]
            end
          end
        end
      rescue LoadError
        [501, {"content-type" => "application/json"},
         [JSON.generate(error: "brute_flow gem not installed")]]
      rescue => e
        [500, {"content-type" => "application/json"},
         [JSON.generate(error: e.message)]]
      end
    end
  end
end
