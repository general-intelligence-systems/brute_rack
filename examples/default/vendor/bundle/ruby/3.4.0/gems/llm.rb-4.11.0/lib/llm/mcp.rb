# frozen_string_literal: true

##
# The {LLM::MCP LLM::MCP} class provides access to servers that
# implement the Model Context Protocol. MCP defines a standard way for
# clients and servers to exchange capabilities such as tools, prompts,
# resources, and other structured interactions.
#
# In llm.rb, {LLM::MCP LLM::MCP} currently supports stdio and HTTP
# transports and focuses on discovering tools that can be used through
# {LLM::Context LLM::Context} and {LLM::Agent LLM::Agent}.
#
# Like {LLM::Context LLM::Context}, an MCP client is stateful and is
# expected to remain isolated to a single thread.
class LLM::MCP
  require_relative "mcp/error"
  require_relative "mcp/command"
  require_relative "mcp/rpc"
  require_relative "mcp/pipe"
  require_relative "mcp/transport/http"
  require_relative "mcp/transport/stdio"

  include RPC

  @@clients = {}

  ##
  # @api private
  def self.clients = @@clients

  ##
  # Builds an MCP client that uses the stdio transport.
  # @param [LLM::Provider, nil] llm
  #  An instance of LLM::Provider. Optional.
  # @param [Hash] stdio
  #  The stdio transport configuration
  # @return [LLM::MCP]
  def self.stdio(llm = nil, **stdio)
    new(llm, stdio:)
  end

  ##
  # Builds an MCP client that uses the HTTP transport.
  # @param [LLM::Provider, nil] llm
  #  An instance of LLM::Provider. Optional.
  # @param [Hash] http
  #  The HTTP transport configuration
  # @return [LLM::MCP]
  def self.http(llm = nil, **http)
    new(llm, http:)
  end

  ##
  # @param [LLM::Provider, nil] llm
  #  The provider to use for MCP transports that need one
  # @param [Hash, nil] stdio The configuration for the stdio transport
  # @option stdio [Array<String>] :argv
  #  The command to run for the MCP process
  # @option stdio [Hash] :env
  #  The environment variables to set for the MCP process
  # @option stdio [String, nil] :cwd
  #  The working directory for the MCP process
  # @param [Hash, nil] http The configuration for the HTTP transport
  # @option http [String] :url
  #  The URL for the MCP HTTP endpoint
  # @option http [Hash] :headers
  #  Extra headers for requests
  # @param [Integer] timeout
  #  The maximum amount of time to wait when reading from an MCP process
  # @return [LLM::MCP] A new MCP instance
  def initialize(llm = nil, stdio: nil, http: nil, timeout: 30)
    @llm = llm
    @timeout = timeout
    if stdio && http
      raise ArgumentError, "stdio and http are mutually exclusive"
    elsif stdio
      @command = Command.new(**stdio)
      @transport = Transport::Stdio.new(command:)
    elsif http
      @transport = Transport::HTTP.new(**http, timeout:)
    else
      raise ArgumentError, "stdio or http is required"
    end
  end

  ##
  # Starts the MCP process.
  # @return [void]
  def start
    transport.start
    call(transport, "initialize", {clientInfo: {name: "llm.rb", version: LLM::VERSION}})
    call(transport, "notifications/initialized")
  end

  ##
  # Stops the MCP process.
  # @return [void]
  def stop
    transport.stop
    nil
  end

  ##
  # Configures an HTTP MCP transport to use a persistent connection pool
  # via the optional dependency [Net::HTTP::Persistent](https://github.com/drbrain/net-http-persistent)
  # @example
  #   mcp = LLM.mcp(http: {url: "https://example.com/mcp"}).persist!
  #   # do something with 'mcp'
  # @return [LLM::MCP]
  def persist!
    transport.persist!
    self
  end

  ##
  # Returns the tools provided by the MCP process.
  # @return [Array<Class<LLM::Tool>>]
  def tools
    res = call(transport, "tools/list")
    res["tools"].map { LLM::Tool.mcp(self, _1) }
  end

  ##
  # Calls a tool by name with the given arguments
  # @param [String] name The name of the tool to call
  # @param [Hash] arguments The arguments to pass to the tool
  # @return [Object] The result of the tool call
  def call_tool(name, arguments = {})
    res = call(transport, "tools/call", {name:, arguments:})
    adapt_tool_result(res)
  end

  private

  attr_reader :llm, :command, :transport, :timeout

  def adapt_tool_result(result)
    if result["structuredContent"]
      result["structuredContent"]
    elsif result["content"]
      {content: result["content"]}
    else
      result
    end
  end
end
