# -*- encoding: utf-8 -*-
# stub: llm.rb 4.11.0 ruby lib

Gem::Specification.new do |s|
  s.name = "llm.rb".freeze
  s.version = "4.11.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://0x1eef.github.io/x/llm.rb/file.CHANGELOG.html", "documentation_uri" => "https://0x1eef.github.io/x/llm.rb", "homepage_uri" => "https://github.com/llmrb/llm.rb", "source_code_uri" => "https://github.com/llmrb/llm.rb" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Antar Azri".freeze, "0x1eef".freeze, "Christos Maris".freeze, "Rodrigo Serrano".freeze]
  s.date = "1980-01-02"
  s.description = "llm.rb is a Ruby-centric toolkit for building real LLM-powered systems \u2014 where\nLLMs are part of your architecture, not just API calls. It gives you explicit\ncontrol over contexts, tools, concurrency, and providers, so you can compose\nreliable, production-ready workflows without hidden abstractions.\n\nBuilt for engineers who want to understand and control their LLM systems. No\nframeworks, no hidden magic \u2014 just composable primitives for building real\napplications, from scripts to full systems like Relay.\n\n## Key Features\n\n- **Contexts are central** \u2014 Hold history, tools, schema, usage, cost, persistence, and execution state\n- **Tool execution is explicit** \u2014 Run local, provider-native, and MCP tools sequentially or concurrently\n- **One API across providers** \u2014 Unified interface for OpenAI, Anthropic, Google, xAI, zAI, DeepSeek, Ollama, and LlamaCpp\n- **Thread-safe where it matters** \u2014 Providers are shareable, while contexts stay isolated and stateful\n- **Production-ready** \u2014 Cost tracking, observability, persistence, and performance tuning built in\n- **Stdlib-only by default** \u2014 Runs on Ruby standard library, with optional features loaded only when used\n\n## Capabilities\n\n- Chat & Contexts with persistence\n- Streaming responses\n- Tool calling with JSON Schema validation\n- Concurrent execution (threads, fibers, async tasks)\n- Agents with auto-execution\n- Structured outputs\n- MCP (Model Context Protocol) support\n- Multimodal inputs (text, images, audio, documents)\n- Audio generation, transcription, translation\n- Image generation and editing\n- Files API for document processing\n- Embeddings and vector stores\n- Local model registry for capabilities, limits, and pricing\n".freeze
  s.email = ["azantar@proton.me".freeze, "0x1eef@hardenedbsd.org".freeze]
  s.homepage = "https://github.com/llmrb/llm.rb".freeze
  s.licenses = ["0BSD".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2.0".freeze)
  s.rubygems_version = "3.6.9".freeze
  s.summary = "llm.rb is a Ruby-centric toolkit for building real LLM-powered systems \u2014 where LLMs are part of your architecture, not just API calls. It gives you explicit control over contexts, tools, concurrency, and providers, so you can compose reliable, production-ready workflows without hidden abstractions.".freeze

  s.installed_by_version = "3.7.2".freeze

  s.specification_version = 4

  s.add_development_dependency(%q<webmock>.freeze, ["~> 3.24.0".freeze])
  s.add_development_dependency(%q<yard>.freeze, ["~> 0.9.37".freeze])
  s.add_development_dependency(%q<kramdown>.freeze, ["~> 2.4".freeze])
  s.add_development_dependency(%q<webrick>.freeze, ["~> 1.8".freeze])
  s.add_development_dependency(%q<test-cmd.rb>.freeze, ["~> 0.12.0".freeze])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0".freeze])
  s.add_development_dependency(%q<standard>.freeze, ["~> 1.50".freeze])
  s.add_development_dependency(%q<vcr>.freeze, ["~> 6.0".freeze])
  s.add_development_dependency(%q<dotenv>.freeze, ["~> 2.8".freeze])
  s.add_development_dependency(%q<net-http-persistent>.freeze, ["~> 4.0".freeze])
  s.add_development_dependency(%q<opentelemetry-sdk>.freeze, ["~> 1.10".freeze])
  s.add_development_dependency(%q<logger>.freeze, ["~> 1.7".freeze])
end
