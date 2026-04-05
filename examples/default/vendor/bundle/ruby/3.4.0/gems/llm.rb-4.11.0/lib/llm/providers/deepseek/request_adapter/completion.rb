# frozen_string_literal: true

module LLM::DeepSeek::RequestAdapter
  ##
  # @private
  class Completion
    ##
    # @param [LLM::Message, Hash] message
    #  The message to format
    def initialize(message)
      @message = message
    end

    ##
    # Adapts the message for the DeepSeek chat completions API
    # @return [Hash]
    def adapt
      catch(:abort) do
        if Hash === message
          {role: message[:role], content: adapt_content(message[:content])}
        elsif message.tool_call?
          {role: message.role, content: nil, tool_calls: message.extra[:original_tool_calls]}
        else
          adapt_message
        end
      end
    end

    private

    def adapt_content(content)
      case content
      when String
        content.to_s
      when LLM::Message
        adapt_content(content.content)
      when LLM::Function::Return
        throw(:abort, {role: "tool", tool_call_id: content.id, content: LLM.json.dump(content.value)})
      when LLM::Object
        prompt_error!(content)
      else
        prompt_error!(content)
      end
    end

    def adapt_message
      case content
      when Array
        adapt_array
      else
        {role: message.role, content: adapt_content(content)}
      end
    end

    def adapt_array
      if content.empty?
        nil
      elsif returns.any?
        returns.map { {role: "tool", tool_call_id: _1.id, content: LLM.json.dump(_1.value)} }
      else
        {role: message.role, content: content.flat_map { adapt_content(_1) }}
      end
    end

    def prompt_error!(object)
      if LLM::Object === object
        raise LLM::PromptError, "The given LLM::Object with kind '#{content.kind}' is not " \
                                "supported by the DeepSeek API"
      else
        raise LLM::PromptError, "The given object (an instance of #{object.class}) " \
                                "is not supported by the DeepSeek API"
      end
    end

    def message = @message
    def content = message.content
    def returns = content.grep(LLM::Function::Return)
  end
end
