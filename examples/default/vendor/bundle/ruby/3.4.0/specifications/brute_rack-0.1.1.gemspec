# -*- encoding: utf-8 -*-
# stub: brute_rack 0.1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "brute_rack".freeze
  s.version = "0.1.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Brute Contributors".freeze]
  s.bindir = "exe".freeze
  s.date = "1980-01-02"
  s.description = "Rack app exposing the Brute agent over HTTP with JSON and SSE streaming endpoints. Deploy with Falcon.".freeze
  s.executables = ["brute-client".freeze, "brute-server".freeze, "brute-server-demo".freeze]
  s.files = ["exe/brute-client".freeze, "exe/brute-server".freeze, "exe/brute-server-demo".freeze]
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.7.2".freeze
  s.summary = "HTTP API for the Brute coding agent".freeze

  s.installed_by_version = "3.7.2".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<brute>.freeze, ["~> 0.1".freeze])
  s.add_runtime_dependency(%q<rack>.freeze, ["~> 3.0".freeze])
  s.add_runtime_dependency(%q<async-http>.freeze, ["~> 0.75".freeze])
end
