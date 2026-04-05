# frozen_string_literal: true

class LLM::Ollama
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
    end

    private

    def merge!(chunk)
      chunk.each do |key, value|
        if key == "message"
          if @body[key]
            @body[key]["content"] << value["content"]
            @stream << value["content"] if @stream.respond_to?(:<<)
          else
            @body[key] = value
            @stream << value["content"] if @stream.respond_to?(:<<)
          end
        else
          @body[key] = value
        end
      end
    end
  end
end
