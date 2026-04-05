# frozen_string_literal: true

require "async"

module BruteRack
  module Endpoints
    # POST /prompt/stream — SSE streaming response.
    # Streams content, tool calls, and tool results as they happen.
    #
    # Request: { "message": "...", "cwd": "...", "session_id": "..." }
    # Response: text/event-stream with events:
    #   event: content      data: {"text": "..."}
    #   event: tool_call    data: {"name": "...", "args": {...}}
    #   event: tool_result  data: {"name": "...", "success": true}
    #   event: done         data: {"tools_called": [...], "session_id": "..."}
    #   event: error        data: {"message": "..."}
    #
    module PromptStream
      def self.call(env, cwd:)
        body = JSON.parse(env["rack.input"].read)
        sse = BruteRack::SSE.new

        Async do
          tools_called = []

          session = body["session_id"] ? Brute::Session.new(id: body["session_id"]) : nil

          Brute.agent(
            cwd: body["cwd"] || cwd,
            session: session,
            on_content: ->(text) {
              sse.event("content", text: text) if text
            },
            on_tool_call: ->(name, args) {
              tools_called << name
              sse.event("tool_call", name: name, args: args.is_a?(Hash) ? args : {})
            },
            on_tool_result: ->(name, result) {
              success = !(result.is_a?(Hash) && result[:error])
              sse.event("tool_result", name: name, success: success)
            },
          ).run(body["message"])

          sse.event("done", tools_called: tools_called, session_id: session&.id)
        rescue => e
          sse.event("error", message: e.message)
        ensure
          sse.close
        end

        [200, {"content-type" => "text/event-stream", "cache-control" => "no-cache"}, sse.body]
      end
    end
  end
end
