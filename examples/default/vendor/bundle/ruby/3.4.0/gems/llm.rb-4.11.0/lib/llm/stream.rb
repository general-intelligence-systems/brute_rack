# frozen_string_literal: true

module LLM
  ##
  # The {LLM::Stream LLM::Stream} class provides the callback interface for
  # streamed model output in llm.rb.
  #
  # A stream object can be an instance of {LLM::Stream LLM::Stream}, a
  # subclass that overrides the callbacks it needs, or any other object that
  # implements some or all of the same interface. {#queue} provides a small
  # helper for collecting asynchronous tool work started from a callback, and
  # {#tool_not_found} returns an in-band tool error when a streamed tool
  # cannot be resolved.
  #
  # @note The `on_*` callbacks run inline with the streaming parser. They
  #   therefore block streaming progress and should generally return as
  #   quickly as possible.
  #
  # The most common callback is {#on_content}, which also maps to {#<<} for
  # compatibility with `StringIO`-style objects. Providers may also call
  # {#on_reasoning_content} and {#on_tool_call} when that data is available.
  class Stream
    require_relative "stream/queue"

    ##
    # Returns a lazily-initialized queue for tool results or spawned work.
    # @return [LLM::Stream::Queue]
    def queue
      @queue ||= Queue.new
    end

    ##
    # Waits for queued tool work to finish and returns function results.
    # @param [Symbol] strategy
    #  The concurrency strategy to use
    # @return [Array<LLM::Function::Return>]
    def wait(strategy)
      queue.wait(strategy)
    end

    # @group Public callbacks

    ##
    # Called when visible assistant output is streamed.
    # @param [String] content
    #  A chunk of assistant-visible text.
    # @return [nil]
    def on_content(content)
      nil
    end
    alias_method :<<, :on_content

    ##
    # Called when reasoning output is streamed separately from visible content.
    # @param [String] content
    #  A chunk of reasoning text.
    # @return [nil]
    def on_reasoning_content(content)
      nil
    end

    ##
    # Called when a streamed tool call has been fully constructed.
    # @note A stream implementation may start tool execution here, for
    #   example by pushing `tool.spawn(:thread)`, `tool.spawn(:fiber)`, or
    #   `tool.spawn(:task)` onto {#queue}. When a streamed tool cannot be
    #   resolved, `error` is passed as an {LLM::Function::Return}. It can be
    #   sent back to the model, allowing the tool-call path to recover and the
    #   session to continue. Tool resolution depends on
    #   {LLM::Function.registry}, which includes {LLM::Tool LLM::Tool}
    #   subclasses, including MCP tools, but not functions defined with
    #   {LLM.function}.
    # @param [LLM::Function] tool
    #  The parsed tool call.
    # @param [LLM::Function::Return, nil] error
    #  An in-band tool error for unresolved tool calls.
    # @return [nil]
    def on_tool_call(tool, error)
      nil
    end

    # @endgroup

    # @group Error handlers

    ##
    # Returns a function return describing a streamed tool that could not
    # be resolved.
    # @note This is mainly useful as a fallback from {#on_tool_call}. It
    #   should be uncommon in normal use, since streamed tool callbacks only
    #   run for tools already defined in the context.
    # @param [LLM::Function] tool
    # @return [LLM::Function::Return]
    def tool_not_found(tool)
      LLM::Function::Return.new(tool.id, tool.name, {
        error: true, type: LLM::NoSuchToolError.name, message: "tool not found"
      })
    end

    # @endgroup
  end
end
