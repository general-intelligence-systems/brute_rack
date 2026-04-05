# -*- encoding: utf-8 -*-
# stub: brute 0.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "brute".freeze
  s.version = "0.1.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Brute Contributors".freeze]
  s.date = "1980-01-02"
  s.description = "Production-grade coding agent with tool execution, middleware pipeline, context compaction, session persistence, and multi-provider LLM support.".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.7.2".freeze
  s.summary = "A coding agent built on llm.rb".freeze

  s.installed_by_version = "3.7.2".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<llm.rb>.freeze, ["~> 4.11".freeze])
  s.add_runtime_dependency(%q<async>.freeze, ["~> 2.0".freeze])
end
