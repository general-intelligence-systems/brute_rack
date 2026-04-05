# frozen_string_literal: true

module LLM::OpenAI::RequestAdapter
  ##
  # @private
  class Respond
    ##
    # @param [LLM::Message] message
    #  The message to format
    def initialize(message)
      @message = message
    end

    def adapt
      catch(:abort) do
        if Hash === message
          {role: message[:role], content: adapt_content(message[:content])}
        else
          adapt_message
        end
      end
    end

    private

    def adapt_content(content)
      case content
      when String
        [{type: :input_text, text: content.to_s}]
      when LLM::Response then adapt_remote_file(content)
      when LLM::Message then adapt_content(content.content)
      when LLM::Object
        case content.kind
        when :image_url then [{type: :image_url, image_url: {url: content.value.to_s}}]
        when :remote_file then adapt_remote_file(content.value)
        when :local_file then prompt_error!(content)
        else prompt_error!(content)
        end
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
        returns.map { {type: "function_call_output", call_id: _1.id, output: LLM.json.dump(_1.value)} }
      else
        {role: message.role, content: content.flat_map { adapt_content(_1) }}
      end
    end

    def adapt_remote_file(content)
      prompt_error!(content) unless content.file?
      file = LLM::File(content.filename)
      if file.image?
        [{type: :input_image, file_id: content.id}]
      else
        [{type: :input_file, file_id: content.id}]
      end
    end

    def prompt_error!(content)
      if LLM::Object === content
        raise LLM::PromptError, "The given LLM::Object with kind '#{content.kind}' is not " \
                                "supported by the OpenAI responses API."
      else
        raise LLM::PromptError, "The given object (an instance of #{content.class}) " \
                                "is not supported by the OpenAI responses API"
      end
    end

    def message = @message
    def content = message.content
    def returns = content.grep(LLM::Function::Return)
  end
end
