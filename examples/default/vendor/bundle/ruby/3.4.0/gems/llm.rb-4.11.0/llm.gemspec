# frozen_string_literal: true

require_relative "lib/llm/version"

Gem::Specification.new do |spec|
  spec.name = "llm.rb"
  spec.version = LLM::VERSION
  spec.authors = ["Antar Azri", "0x1eef", "Christos Maris", "Rodrigo Serrano"]
  spec.email = ["azantar@proton.me", "0x1eef@hardenedbsd.org"]

  spec.summary = <<~SUMMARY
  llm.rb is a Ruby-centric toolkit for building real LLM-powered systems — where
  LLMs are part of your architecture, not just API calls. It gives you explicit
  control over contexts, tools, concurrency, and providers, so you can compose
  reliable, production-ready workflows without hidden abstractions.
  SUMMARY

  spec.description = <<~DESCRIPTION
  llm.rb is a Ruby-centric toolkit for building real LLM-powered systems — where
  LLMs are part of your architecture, not just API calls. It gives you explicit
  control over contexts, tools, concurrency, and providers, so you can compose
  reliable, production-ready workflows without hidden abstractions.

  Built for engineers who want to understand and control their LLM systems. No
  frameworks, no hidden magic — just composable primitives for building real
  applications, from scripts to full systems like Relay.

  ## Key Features

  - **Contexts are central** — Hold history, tools, schema, usage, cost, persistence, and execution state
  - **Tool execution is explicit** — Run local, provider-native, and MCP tools sequentially or concurrently
  - **One API across providers** — Unified interface for OpenAI, Anthropic, Google, xAI, zAI, DeepSeek, Ollama, and LlamaCpp
  - **Thread-safe where it matters** — Providers are shareable, while contexts stay isolated and stateful
  - **Production-ready** — Cost tracking, observability, persistence, and performance tuning built in
  - **Stdlib-only by default** — Runs on Ruby standard library, with optional features loaded only when used

  ## Capabilities

  - Chat & Contexts with persistence
  - Streaming responses
  - Tool calling with JSON Schema validation
  - Concurrent execution (threads, fibers, async tasks)
  - Agents with auto-execution
  - Structured outputs
  - MCP (Model Context Protocol) support
  - Multimodal inputs (text, images, audio, documents)
  - Audio generation, transcription, translation
  - Image generation and editing
  - Files API for document processing
  - Embeddings and vector stores
  - Local model registry for capabilities, limits, and pricing
  DESCRIPTION

  spec.license = "0BSD"
  spec.required_ruby_version = ">= 3.2.0"

  spec.homepage = "https://github.com/llmrb/llm.rb"
  spec.metadata["homepage_uri"] = "https://github.com/llmrb/llm.rb"
  spec.metadata["source_code_uri"] = "https://github.com/llmrb/llm.rb"
  spec.metadata["documentation_uri"] = "https://0x1eef.github.io/x/llm.rb"
  spec.metadata["changelog_uri"] = "https://0x1eef.github.io/x/llm.rb/file.CHANGELOG.html"

  spec.files = Dir[
    "README.md", "LICENSE",
    "lib/*.rb", "lib/**/*.rb",
    "data/*.json", "CHANGELOG.md",
    "llm.gemspec"
  ]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "webmock", "~> 3.24.0"
  spec.add_development_dependency "yard", "~> 0.9.37"
  spec.add_development_dependency "kramdown", "~> 2.4"
  spec.add_development_dependency "webrick", "~> 1.8"
  spec.add_development_dependency "test-cmd.rb", "~> 0.12.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "standard", "~> 1.50"
  spec.add_development_dependency "vcr", "~> 6.0"
  spec.add_development_dependency "dotenv", "~> 2.8"
  spec.add_development_dependency "net-http-persistent", "~> 4.0"
  spec.add_development_dependency "opentelemetry-sdk", "~> 1.10"
  spec.add_development_dependency "logger", "~> 1.7"
end
