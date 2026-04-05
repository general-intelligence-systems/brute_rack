# frozen_string_literal: true

module BruteRack
  module Endpoints
    # POST /prompt — blocking JSON response.
    # Runs the agent to completion, returns the full result.
    #
    # Request:  { "message": "...", "cwd": "...", "session_id": "..." }
    # Response: { "response": "...", "tools_called": [...], "session_id": "..." }
    #
    module Prompt
      def self.call(env, cwd:)
        JSON.parse(env["rack.input"].read).then do |body|
          tools_called = []

          session = body["session_id"] ? Brute::Session.new(id: body["session_id"]) : nil

          Brute.agent(
            cwd: body["cwd"] || cwd,
            session: session,
            on_tool_call: ->(name, _) { tools_called << name },
          ).run(body["message"]).then do |response|
            [200, {"content-type" => "application/json"},
             [JSON.generate(
               response: response&.content,
               tools_called: tools_called,
               session_id: session&.id,
             )]]
          end
        end
      rescue => e
        [500, {"content-type" => "application/json"},
         [JSON.generate(error: e.message)]]
      end
    end
  end
end
