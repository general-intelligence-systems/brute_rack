# frozen_string_literal: true

module LLM
  ##
  # {LLM::Agent LLM::Agent} provides a class-level DSL for defining
  # reusable, preconfigured assistants with defaults for model,
  # tools, schema, and instructions.
  #
  # **Notes:**
  # * Instructions are injected only on the first request.
  # * An agent will automatically execute tool calls (unlike {LLM::Context LLM::Context}).
  # * The idea originally came from RubyLLM and was adapted to llm.rb.
  #
  # @example
  #   class SystemAdmin < LLM::Agent
  #     model "gpt-4.1-nano"
  #     instructions "You are a Linux system admin"
  #     tools Shell
  #     schema Result
  #   end
  #
  #   llm = LLM.openai(key: ENV["KEY"])
  #   agent = SystemAdmin.new(llm)
  #   agent.talk("Run 'date'")
  class Agent
    ##
    # Returns a provider
    # @return [LLM::Provider]
    attr_reader :llm

    ##
    # Set or get the default model
    # @param [String, nil] model
    #  The model identifier
    # @return [String, nil]
    #  Returns the current model when no argument is provided
    def self.model(model = nil)
      return @model if model.nil?
      @model = model
    end

    ##
    # Set or get the default tools
    # @param [Array<LLM::Function>, nil] tools
    #  One or more tools
    # @return [Array<LLM::Function>]
    #  Returns the current tools when no argument is provided
    def self.tools(*tools)
      return @tools || [] if tools.empty?
      @tools = tools.flatten
    end

    ##
    # Set or get the default schema
    # @param [#to_json, nil] schema
    #  The schema
    # @return [#to_json, nil]
    #  Returns the current schema when no argument is provided
    def self.schema(schema = nil)
      return @schema if schema.nil?
      @schema = schema
    end

    ##
    # Set or get the default instructions
    # @param [String, nil] instructions
    #  The system instructions
    # @return [String, nil]
    #  Returns the current instructions when no argument is provided
    def self.instructions(instructions = nil)
      return @instructions if instructions.nil?
      @instructions = instructions
    end

    ##
    # @param [LLM::Provider] provider
    #  A provider
    # @param [Hash] params
    #  The parameters to maintain throughout the conversation.
    #  Any parameter the provider supports can be included and
    #  not only those listed here.
    # @option params [String] :model Defaults to the provider's default model
    # @option params [Array<LLM::Function>, nil] :tools Defaults to nil
    # @option params [#to_json, nil] :schema Defaults to nil
    def initialize(llm, params = {})
      defaults = {model: self.class.model, tools: self.class.tools, schema: self.class.schema}.compact
      @llm = llm
      @ctx = LLM::Context.new(llm, defaults.merge(params))
    end

    ##
    # Maintain a conversation via the chat completions API.
    # This method immediately sends a request to the LLM and returns the response.
    #
    # @param prompt (see LLM::Provider#complete)
    # @param [Hash] params The params passed to the provider, including optional :stream, :tools, :schema etc.
    # @option params [Integer] :max_tool_rounds The maxinum number of tool call iterations (default 10)
    # @return [LLM::Response] Returns the LLM's response for this turn.
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   agent = LLM::Agent.new(llm)
    #   response = agent.talk("Hello, what is your name?")
    #   puts response.choices[0].content
    def talk(prompt, params = {})
      i, max = 0, Integer(params.delete(:max_tool_rounds) || 10)
      res = @ctx.talk(apply_instructions(prompt), params)
      until @ctx.functions.empty?
        raise LLM::ToolLoopError, "pending tool calls remain" if i >= max
        res = @ctx.talk @ctx.functions.map(&:call), params
        i += 1
      end
      res
    end
    alias_method :chat, :talk

    ##
    # Maintain a conversation via the responses API.
    # This method immediately sends a request to the LLM and returns the response.
    #
    # @note Not all LLM providers support this API
    # @param prompt (see LLM::Provider#complete)
    # @param [Hash] params The params passed to the provider, including optional :stream, :tools, :schema etc.
    # @option params [Integer] :max_tool_rounds The maxinum number of tool call iterations (default 10)
    # @return [LLM::Response] Returns the LLM's response for this turn.
    # @example
    #   llm = LLM.openai(key: ENV["KEY"])
    #   agent = LLM::Agent.new(llm)
    #   res = agent.respond("What is the capital of France?")
    #   puts res.output_text
    def respond(prompt, params = {})
      i, max = 0, Integer(params.delete(:max_tool_rounds) || 10)
      res = @ctx.respond(apply_instructions(prompt), params)
      until @ctx.functions.empty?
        raise LLM::ToolLoopError, "pending tool calls remain" if i >= max
        res = @ctx.respond @ctx.functions.map(&:call), params
        i += 1
      end
      res
    end

    ##
    # @return [LLM::Buffer<LLM::Message>]
    def messages
      @ctx.messages
    end

    ##
    # @return [Array<LLM::Function>]
    def functions
      @ctx.functions
    end

    ##
    # @return [LLM::Object]
    def usage
      @ctx.usage
    end

    ##
    # @param (see LLM::Context#prompt)
    # @return (see LLM::Context#prompt)
    # @see LLM::Context#prompt
    def prompt(&b)
      @ctx.prompt(&b)
    end
    alias_method :build_prompt, :prompt

    ##
    # @param [String] url
    #  The URL
    # @return [LLM::Object]
    #  Returns a tagged object
    def image_url(url)
      @ctx.image_url(url)
    end

    ##
    # @param [String] path
    #  The path
    # @return [LLM::Object]
    #  Returns a tagged object
    def local_file(path)
      @ctx.local_file(path)
    end

    ##
    # @param [LLM::Response] res
    #  The response
    # @return [LLM::Object]
    #  Returns a tagged object
    def remote_file(res)
      @ctx.remote_file(res)
    end

    ##
    # @return [LLM::Tracer]
    #  Returns an LLM tracer
    def tracer
      @ctx.tracer
    end

    ##
    # Returns the model an Agent is actively using
    # @return [String]
    def model
      @ctx.model
    end

    ##
    # @param (see LLM::Context#serialize)
    # @return (see LLM::Context#serialize)
    def serialize(**kw)
      @ctx.serialize(**kw)
    end
    alias_method :save, :serialize

    ##
    # @param (see LLM::Context#deserialize)
    # @return (see LLM::Context#deserialize)
    def deserialize(**kw)
      @ctx.deserialize(**kw)
    end
    alias_method :restore, :deserialize

    private

    ##
    # @return [LLM::Prompt]
    def apply_instructions(new_prompt)
      instr = self.class.instructions
      return new_prompt unless instr
      if LLM::Prompt === new_prompt
        @ctx.messages.empty? ? new_prompt.system(instr) : nil
        new_prompt
      else
        prompt do
          @ctx.messages.empty? ? _1.system(instr) : nil
          _1.user(new_prompt)
        end
      end
    end
  end
end
