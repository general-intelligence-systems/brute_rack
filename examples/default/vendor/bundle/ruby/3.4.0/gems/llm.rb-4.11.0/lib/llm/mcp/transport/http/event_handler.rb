# frozen_string_literal: true

module LLM::MCP::Transport
  ##
  # The {LLM::MCP::Transport::HTTP::EventHandler LLM::MCP::Transport::HTTP::EventHandler}
  # class adapts generic server-sent event callbacks into decoded JSON-RPC
  # messages for {LLM::MCP::Transport::HTTP LLM::MCP::Transport::HTTP}.
  # It accumulates event data until a blank line terminates the current
  # event, then parses the payload as JSON and yields it to the callback
  # given at initialization.
  # @private
  class HTTP::EventHandler
    ##
    # @yieldparam [Hash] message
    #  A decoded JSON-RPC message
    # @return [LLM::MCP::Transport::HTTP::EventHandler]
    def initialize(&on_message)
      @on_message = on_message
      reset
    end

    ##
    # Receives the SSE event name.
    # @param [LLM::EventStream::Event] event
    #  The event stream event
    # @return [void]
    def on_event(event)
      @event = event.value
    end

    ##
    # Receives one line of SSE data.
    # @param [LLM::EventStream::Event] event
    #  The event stream event
    # @return [void]
    def on_data(event)
      @data << event.value.to_s
    end

    # The generic event stream parser dispatches one line at a time.
    # A blank line terminates the current SSE event.
    # @param [LLM::EventStream::Event] event
    #  The event stream event
    # @return [void]
    def on_chunk(event)
      flush if event.chunk == "\n"
    end

    private

    def flush
      return reset if @data.empty? && @event.nil?
      payload = @data.join("\n")
      reset
      return if payload.empty? || payload == "[DONE]"
      @on_message.call(LLM.json.load(payload))
    rescue *LLM.json.parser_error
      reset
    end

    def reset
      @event = nil
      @data = []
    end
  end
end
