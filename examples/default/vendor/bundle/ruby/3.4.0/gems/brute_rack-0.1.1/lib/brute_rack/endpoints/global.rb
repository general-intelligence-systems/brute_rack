# frozen_string_literal: true

require "async"

module BruteRack
  module Endpoints
    # GET /global/health  → { healthy: true, version: "..." }
    # GET /global/event   → SSE stream of all bus events
    module Global
      def self.health(_env, **)
        [200, HEADERS_JSON,
         [JSON.generate(healthy: true, version: Brute::VERSION)]]
      end

      def self.event(_env, event_bus:, **)
        sse = BruteRack::SSE.new

        subscriber = event_bus.subscribe do |event|
          sse.event(event[:type], **(event[:data] || {}), session_id: event[:session_id])
        end

        # Send initial connected event
        sse.event("server.connected", version: Brute::VERSION)

        # Keep the stream open until the client disconnects.
        # Falcon will detect the closed connection and raise Async::Stop
        # which tears down the task, at which point we unsubscribe.
        Async do
          sleep # block forever — events are pushed by the bus
        rescue
          # Client disconnected or server shutting down
        ensure
          event_bus.unsubscribe(subscriber)
          sse.close
        end

        [200, {"content-type" => "text/event-stream", "cache-control" => "no-cache"}, sse.body]
      end
    end
  end
end
