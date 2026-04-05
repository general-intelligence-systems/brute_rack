# frozen_string_literal: true

##
# The {LLM::Function LLM::Function} class represents a local
# function that can be called by an LLM.
#
# @example example #1
#   LLM.function(:system) do |fn|
#     fn.name "system"
#     fn.description "Runs system commands"
#     fn.params do |schema|
#       schema.object(command: schema.string.required)
#     end
#     fn.define do |command:|
#       {success: Kernel.system(command)}
#     end
#   end
#
# @example example #2
#   class System < LLM::Tool
#     name "system"
#     description "Runs system commands"
#     params do |schema|
#       schema.object(command: schema.string.required)
#     end
#
#     def call(command:)
#       {success: Kernel.system(command)}
#     end
#   end
class LLM::Function
  require_relative "function/registry"
  require_relative "function/tracing"
  require_relative "function/array"
  require_relative "function/task"
  require_relative "function/thread_group"
  require_relative "function/fiber_group"
  require_relative "function/task_group"

  extend LLM::Function::Registry
  prepend LLM::Function::Tracing

  Return = Struct.new(:id, :name, :value) do
    ##
    # Returns a Hash representation of {LLM::Function::Return}
    # @return [Hash]
    def to_h
      {id:, name:, value:}
    end

    ##
    # @return [String]
    def to_json(...)
      LLM.json.dump(to_h, ...)
    end
  end

  ##
  # Returns the function ID
  # @return [String, nil]
  attr_accessor :id

  ##
  # Returns function arguments
  # @return [Array, nil]
  attr_accessor :arguments

  ##
  # Returns a tracer, or nil
  # @return [LLM::Tracer, nil]
  attr_accessor :tracer

  ##
  # Returns a model name, or nil
  # @return [String, nil]
  attr_accessor :model

  ##
  # @param [String] name The function name
  # @yieldparam [LLM::Function] self The function object
  def initialize(name, &b)
    @name = name
    @schema = LLM::Schema.new
    @called = false
    @cancelled = false
    yield(self) if block_given?
  end

  ##
  # Set (or get) the function name
  # @param [String] name The function name
  # @return [void]
  def name(name = nil)
    if name
      @name = name.to_s
    else
      @name
    end
  end

  ##
  # Set (or get) the function description
  # @param [String] desc The function description
  # @return [void]
  def description(desc = nil)
    if desc
      @description = desc
    else
      @description
    end
  end

  ##
  # Set (or get) the function parameters
  # @yieldparam [LLM::Schema] schema The schema object
  # @return [LLM::Schema::Leaf, nil]
  def params
    if block_given?
      params = yield(@schema)
      params = LLM::Schema.parse(params) if Hash === params
      if @params
        @params.merge!(params)
      else
        @params = params
      end
    else
      @params
    end
  end

  ##
  # Set the function implementation
  # @param [Proc, Class] b The function implementation
  # @return [void]
  def define(klass = nil, &b)
    @runner = klass || b
  end
  alias_method :register, :define

  ##
  # Call the function
  # @return [LLM::Function::Return] The result of the function call
  def call
    call_function
  ensure
    @called = true
  end

  ##
  # Calls the function concurrently.
  #
  # This is the low-level method that powers concurrent tool execution.
  # Prefer the collection methods on {LLM::Context#functions} for most
  # use cases: {LLM::Function::Array#call}, {LLM::Function::Array#wait},
  # or {LLM::Function::Array#spawn}.
  #
  # @example
  #   # Normal usage (via collection)
  #   ctx.talk(ctx.functions.wait)
  #
  #   # Direct usage (uncommon)
  #   task = tool.spawn(:thread)
  #   result = task.value
  #
  # @param [Symbol] strategy
  #   Controls concurrency strategy:
  #   - `:thread`: Use threads
  #   - `:task`: Use async tasks (requires async gem)
  #   - `:fiber`: Use raw fibers
  #
  # @return [LLM::Function::Task]
  #   Returns a task whose `#value` is an {LLM::Function::Return}.
  def spawn(strategy)
    task = case strategy
    when :task
      require "async" unless defined?(::Async)
      Async { call_function }
    when :thread
      Thread.new { call_function }
    when :fiber
      Fiber.new do
        call_function
      ensure
        Fiber.yield
      end.tap(&:resume)
    else
      raise ArgumentError, "Unknown strategy: #{strategy.inspect}. Expected :thread, :task, or :fiber"
    end
    Task.new(task)
  ensure
    @called = true
  end

  ##
  # Returns a value that communicates that the function call was cancelled
  # @example
  #   llm = LLM.openai(key: ENV["KEY"])
  #   ctx = LLM::Context.new(llm, tools: [fn1, fn2])
  #   ctx.talk "I want to run the functions"
  #   ctx.talk ctx.functions.map(&:cancel)
  # @return [LLM::Function::Return]
  def cancel(reason: "function call cancelled")
    Return.new(id, name, {cancelled: true, reason:})
  ensure
    @cancelled = true
  end

  ##
  # Returns true when a function has been called
  # @return [Boolean]
  def called?
    @called
  end

  ##
  # Returns true when a function has been cancelled
  # @return [Boolean]
  def cancelled?
    @cancelled
  end

  ##
  # Returns true when a function has neither been called nor cancelled
  # @return [Boolean]
  def pending?
    !@called && !@cancelled
  end

  ##
  # @return [Hash]
  def adapt(provider)
    case provider.class.to_s
    when "LLM::Google"
      {name: @name, description: @description, parameters: @params}.compact
    when "LLM::Anthropic"
      {name: @name, description: @description, input_schema: @params}.compact
    else
      format_openai(provider)
    end
  end

  private

  def format_openai(provider)
    case provider.class.to_s
    when "LLM::OpenAI::Responses"
      {
        type: "function", name: @name, description: @description,
        parameters: @params.to_h.merge(additionalProperties: false), strict: true
      }.compact
    else
      {
        type: "function", name: @name,
        function: {name: @name, description: @description, parameters: @params}
      }.compact
    end
  end

  ##
  # Internal method that calls the function and returns a Return object.
  # Handles both class-based and proc-based runners, and rescues exceptions.
  #
  # @return [LLM::Function::Return]
  #   Returns a Return object with either the function result or error information.
  def call_function
    runner = ((Class === @runner) ? @runner.new : @runner)
    kwargs = Hash === arguments ? arguments.transform_keys(&:to_sym) : arguments
    Return.new(id, name, runner.call(**kwargs))
  rescue => ex
    Return.new(id, name,  {error: true, type: ex.class.name, message: ex.message})
  end
end
