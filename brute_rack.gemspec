# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "brute_rack"
  spec.version       = "0.1.3"
  spec.authors       = ["Brute Contributors"]
  spec.summary       = "HTTP API for the Brute coding agent"
  spec.description   = "Rack app exposing the Brute agent over HTTP with " \
                        "JSON and SSE streaming endpoints. Deploy with Falcon."
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/general-intelligence-systems/brute_rack"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "documentation_uri" => "https://general-intelligence-systems.github.io/brute_rack/",
  }

  spec.files         = Dir["lib/**/*.rb", "exe/*"]
  spec.bindir        = "exe"
  spec.executables   = ["brute-server", "brute-server-demo", "brute-client"]
  spec.require_paths = ["lib"]

  spec.add_dependency "brute", "~> 0.1"
  spec.add_dependency "rack", "~> 3.0"
  spec.add_dependency "async-http", "~> 0.75"
end
