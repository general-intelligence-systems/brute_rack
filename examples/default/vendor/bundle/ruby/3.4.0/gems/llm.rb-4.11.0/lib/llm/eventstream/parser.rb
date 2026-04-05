# frozen_string_literal: true

module LLM::EventStream
  ##
  # @private
  class Parser
    ##
    # @return [LLM::EventStream::Parser]
    def initialize
      @buffer = +""
      @events = Hash.new { |h, k| h[k] = [] }
      @cursor = 0
      @visitors = []
    end

    ##
    # Register a visitor
    # @param [#on_data] visitor
    # @return [void]
    def register(visitor)
      @visitors << visitor
    end

    ##
    # Subscribe to an event
    # @param [Symbol] evtname
    # @param [Proc] block
    # @return [void]
    def on(evtname, &block)
      @events[evtname.to_s] << block
    end

    ##
    # Append an event to the internal buffer
    # @return [void]
    def <<(event)
      @buffer << event
      each_line { parse!(_1) }
    end

    ##
    # Returns the internal buffer
    # @return [String]
    def body
      @buffer.dup
    end

    ##
    # Free the internal buffer
    # @return [void]
    def free
      @buffer.clear
      @cursor = 0
    end

    private

    def parse!(event)
      event = Event.new(event)
      dispatch(event)
    end

    def dispatch(event)
      @visitors.each { dispatch_visitor(_1, event) }
      @events[event.field].each { _1.call(event) }
    end

    def dispatch_visitor(visitor, event)
      method = "on_#{event.field}"
      if visitor.respond_to?(method)
        visitor.public_send(method, event)
      elsif visitor.respond_to?("on_chunk")
        visitor.on_chunk(event)
      end
    end

    def each_line
      while (newline = @buffer.index("\n", @cursor))
        line = @buffer[@cursor..newline]
        @cursor = newline + 1
        yield(line)
      end
      return if @cursor.zero?
      @buffer = @buffer[@cursor..] || +""
      @cursor = 0
    end
  end
end
