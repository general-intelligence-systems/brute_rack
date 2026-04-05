# frozen_string_literal: true

class LLM::OpenAI
  ##
  # @private
  class StreamParser
    ##
    # Returns the fully constructed response body
    # @return [Hash]
    attr_reader :body

    ##
    # @return [LLM::OpenAI::Chunk]
    def initialize(stream)
      @body = {}
      @stream = stream
      @emits = {tools: []}
    end

    ##
    # @param [Hash] chunk
    # @return [LLM::OpenAI::Chunk]
    def parse!(chunk)
      tap { merge!(chunk) }
    end

    ##
    # Frees internal parser state used during streaming.
    # @return [void]
    def free
      @emits.clear
    end

    private

    def merge!(chunk)
      chunk.each do |key, value|
        if key == "choices"
          @body["choices"] ||= []
          merge_choices!(value)
        else
          @body[key] = value
        end
      end
    end

    def merge_choices!(choices)
      choices.each do |choice|
        index = choice["index"]
        if @body["choices"][index]
          target_message = @body["choices"][index]["message"]
          delta = choice["delta"] || {}
          delta.each do |key, value|
            next if value.nil?
            if key == "content"
              target_message[key] ||= +""
              target_message[key] << value
              emit_content(value)
            elsif key == "reasoning_content"
              target_message[key] ||= +""
              target_message[key] << value
              emit_reasoning_content(value)
            elsif key == "tool_calls"
              merge_tools!(target_message, value)
            else
              target_message[key] = value
            end
          end
        else
          message_hash = {"role" => "assistant"}
          @body["choices"][index] = {"message" => message_hash}
          (choice["delta"] || {}).each do |key, value|
            next if value.nil?
            if key == "content"
              emit_content(value)
              message_hash[key] = value
            elsif key == "reasoning_content"
              emit_reasoning_content(value)
              message_hash[key] = value
            elsif key == "tool_calls"
              merge_tools!(message_hash, value)
            else
              message_hash[key] = value
            end
          end
        end
      end
    end

    def merge_tools!(target, tools)
      target["tool_calls"] ||= []
      tools.each.with_index do |toola, index|
        tindex = toola["index"]
        tindex = index unless Integer === tindex && tindex >= 0
        toolb = target["tool_calls"][tindex]
        if toolb && toola["function"] && toolb["function"]
          # Append to existing function arguments
          toola["function"].each do |func_key, func_value|
            toolb["function"][func_key] ||= +""
            toolb["function"][func_key] << func_value
          end
        else
          target["tool_calls"][tindex] = toola
        end
        emit_tool(target["tool_calls"][tindex], tindex)
      end
    end

    def emit_content(value)
      if @stream.respond_to?(:on_content)
        @stream.on_content(value)
      elsif @stream.respond_to?(:<<)
        @stream << value
      end
    end

    def emit_reasoning_content(value)
      if @stream.respond_to?(:on_reasoning_content)
        @stream.on_reasoning_content(value)
      end
    end

    def emit_tool(tool, tindex)
      return unless @stream.respond_to?(:on_tool_call)
      return unless complete_tool?(tool)
      return if @emits[:tools].include?(tindex)
      function, error = resolve_tool(tool)
      @emits[:tools] << tindex
      @stream.on_tool_call(function, error)
    end

    def complete_tool?(tool)
      function = tool["function"]
      function && tool["id"] && function["name"] && parse_arguments(function["arguments"])
    end

    def resolve_tool(tool)
      function = tool["function"]
      registered = LLM::Function.find_by_name(function["name"])
      fn = (registered || LLM::Function.new(function["name"])).dup.tap do |fn|
        fn.id = tool["id"]
        fn.arguments = parse_arguments(function["arguments"])
      end
      [fn, (registered ? nil : @stream.tool_not_found(fn))]
    end

    def parse_arguments(arguments)
      return nil if arguments.to_s.empty?
      parsed = LLM.json.load(arguments)
      Hash === parsed ? parsed : nil
    rescue *LLM.json.parser_error
      nil
    end
  end
end
