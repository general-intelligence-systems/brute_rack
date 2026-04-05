# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::Task} class wraps a single concurrent function call and
  # provides a small, uniform interface across threads, fibers, and async tasks.
  class Task
    ##
    # @return [Object]
    attr_reader :task

    ##
    # @param [Thread, Fiber, Async::Task] task
    # @return [LLM::Function::Task]
    def initialize(task)
      @task = task
    end

    ##
    # @return [Boolean]
    def alive?
      task.alive?
    end

    ##
    # @return [LLM::Function::Return]
    def wait
      if Thread === task
        task.value
      elsif Fiber === task
        task.resume if task.alive?
        task.value
      else
        task.wait
      end
    end
    alias_method :value, :wait
  end
end
