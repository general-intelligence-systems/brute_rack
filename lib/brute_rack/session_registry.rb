# frozen_string_literal: true

module BruteRack
  # Tracks active orchestrators per session. Enables abort, status queries,
  # and multi-session management without creating throwaway orchestrators.
  #
  #   registry = SessionRegistry.new(event_bus: bus, cwd: "/project")
  #   orch = registry.get_or_create("session-id")
  #   registry.status("session-id")  # => :idle
  #
  class SessionRegistry
    STATUSES = %i[idle running completed errored].freeze

    def initialize(event_bus:, cwd: Dir.pwd)
      @event_bus = event_bus
      @cwd = cwd
      @sessions = {}  # id => { orchestrator:, status:, session: }
      @mutex = Mutex.new
    end

    def get_or_create(id, cwd: nil)
      @mutex.synchronize do
        @sessions[id] ||= build_entry(id, cwd || @cwd)
        @sessions[id][:orchestrator]
      end
    end

    def get(id)
      @mutex.synchronize { @sessions.dig(id, :orchestrator) }
    end

    def session(id)
      @mutex.synchronize { @sessions.dig(id, :session) }
    end

    def status(id)
      @mutex.synchronize { @sessions.dig(id, :status) || :unknown }
    end

    def set_status(id, status)
      @mutex.synchronize do
        @sessions[id][:status] = status if @sessions[id]
      end
      @event_bus.publish(type: "session.status", session_id: id, data: { status: status })
    end

    def all_statuses
      @mutex.synchronize do
        @sessions.transform_values { |v| v[:status] }
      end
    end

    def ids
      @mutex.synchronize { @sessions.keys }
    end

    def remove(id)
      @mutex.synchronize { @sessions.delete(id) }
    end

    def abort(id)
      @mutex.synchronize { @sessions.dig(id, :orchestrator) }&.abort!
      set_status(id, :idle)
      true
    end

    # Run a message through a session's orchestrator with event publishing.
    def run(id, message, cwd: nil)
      orch = get_or_create(id, cwd: cwd)
      set_status(id, :running)
      @event_bus.publish(type: "message.start", session_id: id, data: { message: message })

      orch.run(message).then do |response|
        set_status(id, :idle)
        @event_bus.publish(type: "message.complete", session_id: id, data: {})
        response
      end
    rescue => e
      set_status(id, :errored)
      @event_bus.publish(type: "message.error", session_id: id, data: { error: e.message })
      raise
    end

    private

    def build_entry(id, cwd)
      session = Brute::Session.new(id: id)
      orch = Brute.agent(
        cwd: cwd,
        session: session,
        on_content: ->(text) {
          @event_bus.publish(type: "content.delta", session_id: id, data: { text: text }) if text
        },
        on_tool_call: ->(name, args) {
          @event_bus.publish(type: "tool.call", session_id: id, data: { name: name, args: args.is_a?(Hash) ? args : {} })
        },
        on_tool_result: ->(name, result) {
          success = !(result.is_a?(Hash) && result[:error])
          @event_bus.publish(type: "tool.result", session_id: id, data: { name: name, success: success })
        },
      )
      { orchestrator: orch, session: session, status: :idle }
    end
  end
end
