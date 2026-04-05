# frozen_string_literal: true

module LLM
  ##
  # {LLM::Response LLM::Response} encapsulates a response
  # from an LLM provider. It is returned by all methods
  # that make requests to a provider, and sometimes extended
  # with provider-specific functionality.
  class Response
    require "json"

    ##
    # Returns the HTTP response
    # @return [Net::HTTPResponse]
    attr_reader :res

    ##
    # @param [Net::HTTPResponse] res
    #  HTTP response
    # @return [LLM::Response]
    #  Returns an instance of LLM::Response
    def initialize(res)
      @res = res
    end

    ##
    # Returns the response body
    # @return [LLM::Object, String]
    #  Returns an LLM::Object when the response body is JSON,
    #  otherwise returns a raw string.
    def body
      @res.body
    end

    ##
    # Returns an inspection of the response object
    # @return [String]
    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} @body=#{body.inspect} @res=#{@res.inspect}>"
    end

    ##
    # Returns true if the response is successful
    # @return [Boolean]
    def ok?
      Net::HTTPSuccess === @res
    end

    ##
    # Returns true if the response is from the Files API
    # @return [Boolean]
    def file?
      false
    end

    private

    def method_missing(m, *args, **kwargs, &b)
      if LLM::Object === body
        body.respond_to?(m) ? body[m.to_s] : super
      else
        super
      end
    end

    def respond_to_missing?(m, include_private = false)
      if LLM::Object === body
        body.respond_to?(m)
      else
        false
      end
    end
  end
end
