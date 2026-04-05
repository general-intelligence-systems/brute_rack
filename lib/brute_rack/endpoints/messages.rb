# frozen_string_literal: true

require "async"
require "securerandom"

module BruteRack
  module Endpoints
    # GET    /session/:id/message             → list messages
    # POST   /session/:id/message             → send message (blocking)
    # GET    /session/:id/message/:messageID  → get specific message
    # POST   /session/:id/prompt_async        → send message (fire-and-forget)
    # POST   /session/:id/shell               → execute shell command
    module Messages
      def self.list(_env, id:, registry:, **)
        orch = registry.get(id)
        return [404, HEADERS_JSON, [JSON.generate(error: "session not found")]] unless orch

        orch.context.messages.to_a.compact.each_with_index.map do |msg, i|
          {
            id: i,
            role: msg.respond_to?(:role) ? msg.role.to_s : "unknown",
            content: msg.respond_to?(:content) ? msg.content.to_s[0..10_000] : nil,
            has_tool_calls: msg.respond_to?(:functions) && msg.functions&.any?,
          }
        end.then do |messages|
          [200, HEADERS_JSON, [JSON.generate(messages)]]
        end
      end

      def self.send_message(env, id:, registry:, cwd:, **)
        parse_body(env).then do |body|
          parts = body["parts"]
          text = if parts.is_a?(Array)
            parts.filter_map { |p| p["text"] if p["type"] == "text" }.join("\n")
          else
            body["message"] || body.dig("parts", 0, "text") || ""
          end

          registry.run(id, text, cwd: body["cwd"] || cwd).then do |response|
            message_id = SecureRandom.uuid
            {
              info: { id: message_id, role: "assistant", session_id: id },
              parts: [{ type: "text", text: response&.content }],
            }.then do |result|
              [200, HEADERS_JSON, [JSON.generate(result)]]
            end
          end
        end
      rescue => e
        [500, HEADERS_JSON, [JSON.generate(error: e.message)]]
      end

      def self.get_message(_env, id:, message_id:, registry:, **)
        orch = registry.get(id)
        return [404, HEADERS_JSON, [JSON.generate(error: "session not found")]] unless orch

        idx = message_id.match?(/\A\d+\z/) ? message_id.to_i : nil
        msg = idx ? orch.context.messages.to_a.compact[idx] : nil

        if msg
          {
            info: { id: message_id, role: msg.respond_to?(:role) ? msg.role.to_s : "unknown", session_id: id },
            parts: [{ type: "text", text: msg.respond_to?(:content) ? msg.content.to_s : nil }],
          }.then { |result| [200, HEADERS_JSON, [JSON.generate(result)]] }
        else
          [404, HEADERS_JSON, [JSON.generate(error: "message not found")]]
        end
      end

      def self.prompt_async(env, id:, registry:, cwd:, event_bus:, **)
        parse_body(env).then do |body|
          text = body["message"] || body.dig("parts", 0, "text") || ""

          Async do
            registry.run(id, text, cwd: body["cwd"] || cwd)
          rescue => e
            event_bus.publish(type: "message.error", session_id: id, data: { error: e.message })
          end

          [204, {}, []]
        end
      end

      def self.shell(env, id:, registry:, cwd:, **)
        parse_body(env).then do |body|
          Brute::Tools::Shell.new.call(
            command: body["command"],
            cwd: body["cwd"] || cwd,
          ).then do |result|
            message_id = SecureRandom.uuid
            {
              info: { id: message_id, role: "tool", session_id: id },
              parts: [{ type: "tool-result", name: "shell", result: result }],
            }.then { |r| [200, HEADERS_JSON, [JSON.generate(r)]] }
          end
        end
      rescue => e
        [500, HEADERS_JSON, [JSON.generate(error: e.message)]]
      end

      def self.parse_body(env)
        input = env["rack.input"].read
        input.empty? ? {} : JSON.parse(input)
      end
    end
  end
end
