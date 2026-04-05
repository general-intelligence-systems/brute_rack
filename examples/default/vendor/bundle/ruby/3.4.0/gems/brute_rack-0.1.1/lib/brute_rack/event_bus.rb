# frozen_string_literal: true

module BruteRack
  # In-memory pub/sub event bus. Endpoints publish events, SSE streams subscribe.
  #
  #   bus = EventBus.new
  #   bus.subscribe { |event| puts event }
  #   bus.publish(type: "content.delta", session_id: "abc", data: { text: "hi" })
  #
  class EventBus
    def initialize
      @subscribers = []
      @mutex = Mutex.new
    end

    def publish(event)
      @mutex.synchronize { @subscribers.each { |cb| cb.call(event) } }
    end

    def subscribe(&block)
      @mutex.synchronize { @subscribers << block }
      block
    end

    def unsubscribe(block)
      @mutex.synchronize { @subscribers.delete(block) }
    end

    def subscriber_count
      @mutex.synchronize { @subscribers.size }
    end
  end
end
