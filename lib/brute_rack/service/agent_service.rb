# frozen_string_literal: true

module BruteRack
  module Service
    # Managed::Service that boots a BruteRack::App from evaluator settings.
    #
    # The evaluator provides: host, port, cwd, tools, reasoning, compactor_opts.
    # These are defined as methods in the service block of the user's service.rb.
    #
    class AgentService < Async::Service::Managed::Service
      private def format_title(evaluator, server)
        connections = server.respond_to?(:connection_count) ? " (#{server.connection_count} conn)" : ""
        "#{self.name} [#{evaluator.host}:#{evaluator.port}]#{connections}"
      end

      def run(instance, evaluator)
        require "falcon"

        app = BruteRack::App.new(
          cwd: evaluator.cwd,
          agent_options: {
            tools:          evaluator.tools,
            reasoning:      evaluator.reasoning,
            compactor_opts: evaluator.compactor_opts,
          },
        )

        middleware = Falcon::Server.middleware(app)
        endpoint = Async::HTTP::Endpoint.parse("http://#{evaluator.host}:#{evaluator.port}")
        server = Falcon::Server.new(middleware, endpoint)
        server.run
      end
    end
  end
end
