# frozen_string_literal: true

require "async/http/body/writable"
require "json"

module BruteRack
  # Server-Sent Events helper.
  #
  # Wraps Async::HTTP::Body::Writable to produce SSE-formatted chunks.
  # Falcon streams each write to the client immediately — no buffering.
  #
  #   sse = BruteRack::SSE.new
  #   sse.event("content", text: "Hello")   # writes "event: content\ndata: {...}\n\n"
  #   sse.close                              # signals end of stream
  #   sse.body                               # the streamable body for Rack response
  #
  class SSE
    attr_reader :body

    def initialize
      @body = Async::HTTP::Body::Writable.new
    end

    def event(type, **data)
      @body.write("event: #{type}\ndata: #{JSON.generate(data)}\n\n")
    end

    def close
      @body.close
    end
  end
end
