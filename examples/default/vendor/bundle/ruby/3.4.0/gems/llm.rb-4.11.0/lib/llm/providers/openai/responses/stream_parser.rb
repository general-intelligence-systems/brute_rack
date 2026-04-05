# frozen_string_literal: true

class LLM::OpenAI
  ##
  # @private
  class Responses::StreamParser
    ##
    # Returns the fully constructed response body
    # @return [Hash]
    attr_reader :body

    ##
    # @param [#<<, LLM::Stream] stream
    #  A stream sink that implements {#<<} or the {LLM::Stream} interface
    # @return [LLM::OpenAI::Responses::StreamParser]
    def initialize(stream)
      @body = {"output" => []}
      @stream = stream
      @emits = {tools: []}
    end

    ##
    # @param [Hash] chunk
    # @return [LLM::OpenAI::Responses::StreamParser]
    def parse!(chunk)
      tap { handle_event(chunk) }
    end

    ##
    # Frees internal parser state used during streaming.
    # @return [void]
    def free
      @emits.clear
    end

    private

    def handle_event(chunk)
      case chunk["type"]
      when "response.created"
        chunk.each do |k, v|
          next if k == "type"
          @body[k] = v
        end
        @body["output"] ||= []
      when "response.output_item.added"
        output_index = chunk["output_index"]
        item = chunk["item"]
        @body["output"][output_index] = item
        @body["output"][output_index]["content"] ||= []
      when "response.content_part.added"
        output_index = chunk["output_index"]
        content_index = chunk["content_index"]
        part = chunk["part"]
        @body["output"][output_index] ||= {"content" => []}
        @body["output"][output_index]["content"] ||= []
        @body["output"][output_index]["content"][content_index] = part
      when "response.output_text.delta"
        output_index = chunk["output_index"]
        content_index = chunk["content_index"]
        delta_text = chunk["delta"]
        output_item = @body["output"][output_index]
        if output_item && output_item["content"]
          content_part = output_item["content"][content_index]
          if content_part && content_part["type"] == "output_text"
            content_part["text"] ||= ""
            content_part["text"] << delta_text
            emit_content(delta_text)
          end
        end
      when "response.function_call_arguments.delta"
        output_item = @body["output"][chunk["output_index"]]
        if output_item && output_item["type"] == "function_call"
          output_item["arguments"] ||= +""
          output_item["arguments"] << chunk["delta"]
        end
      when "response.function_call_arguments.done"
        output_item = @body["output"][chunk["output_index"]]
        if output_item && output_item["type"] == "function_call"
          output_item["arguments"] = chunk["arguments"]
          emit_tool(chunk["output_index"], output_item)
        end
      when "response.output_item.done"
        output_index = chunk["output_index"]
        item = chunk["item"]
        @body["output"][output_index] = item
      when "response.content_part.done"
        output_index = chunk["output_index"]
        content_index = chunk["content_index"]
        part = chunk["part"]
        @body["output"][output_index] ||= {"content" => []}
        @body["output"][output_index]["content"] ||= []
        @body["output"][output_index]["content"][content_index] = part
      end
    end

    def emit_content(value)
      if @stream.respond_to?(:on_content)
        @stream.on_content(value)
      elsif @stream.respond_to?(:<<)
        @stream << value
      end
    end

    def emit_tool(index, tool)
      return unless @stream.respond_to?(:on_tool_call)
      return unless complete_tool?(tool)
      return if @emits[:tools].include?(index)
      function, error = resolve_tool(tool)
      @emits[:tools] << index
      @stream.on_tool_call(function, error)
    end

    def complete_tool?(tool)
      tool["call_id"] && tool["name"] && parse_arguments(tool["arguments"])
    end

    def resolve_tool(tool)
      registered = LLM::Function.find_by_name(tool["name"])
      fn = (registered || LLM::Function.new(tool["name"])).dup.tap do |fn|
        fn.id = tool["call_id"]
        fn.arguments = parse_arguments(tool["arguments"])
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
