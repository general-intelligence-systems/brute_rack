# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::Array} module extends the array
  # returned by {LLM::Context#functions} with methods
  # that can call all pending functions sequentially or
  # concurrently. The return values can be reported back
  # to the LLM on the next turn.
  module Array
    ##
    # Calls all functions in a collection sequentially.
    # @return [Array<LLM::Function::Return>]
    #  Returns values to be reported back to the LLM.
    def call
      map(&:call)
    end

    ##
    # Calls all functions in a collection concurrently.
    # This method returns an {LLM::Function::ThreadGroup},
    # {LLM::Function::TaskGroup}, or {LLM::Function::FiberGroup}
    # that can be waited on to access the return values.
    #
    # @param [Symbol] strategy
    #   Controls concurrency strategy:
    #   - `:thread`: Use threads
    #   - `:task`: Use async tasks (requires async gem)
    #   - `:fiber`: Use raw fibers
    #
    # @return [LLM::Function::ThreadGroup, LLM::Function::TaskGroup, LLM::Function::FiberGroup]
    def spawn(strategy)
      case strategy
      when :task
        TaskGroup.new(map { |fn| fn.spawn(:task) })
      when :thread
        ThreadGroup.new(map { |fn| fn.spawn(:thread) })
      when :fiber
        FiberGroup.new(map { |fn| fn.spawn(:fiber) })
      else
        raise ArgumentError, "Unknown strategy: #{strategy.inspect}. Expected :thread, :task, or :fiber"
      end
    end

    ##
    # Calls all functions in a collection concurrently
    # and waits for the return values.
    #
    # @param [Symbol] strategy
    #   Controls concurrency strategy:
    #   - `:thread`: Use threads
    #   - `:task`: Use async tasks (requires async gem)
    #   - `:fiber`: Use raw fibers
    #
    # @return [Array<LLM::Function::Return>]
    #  Returns values to be reported back to the LLM.
    def wait(strategy)
      spawn(strategy).wait
    end
  end
end
