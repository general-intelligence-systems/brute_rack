# Getting Started

This guide walks you through setting up brute_rack to expose the Brute agent over HTTP.

## Install

```ruby
gem "brute_rack"
```

## Overview

brute_rack is a Rack application that exposes the [Brute](https://github.com/general-intelligence-systems/brute) coding agent over HTTP with JSON and SSE streaming endpoints. Deploy with [Falcon](https://github.com/socketry/falcon).

## Executables

- `brute-server` -- start the HTTP server
- `brute-server-demo` -- start a demo server
- `brute-client` -- command-line HTTP client

## Endpoints

The Rack app provides endpoints for:

- Sessions -- create, list, and manage agent sessions
- Messages -- send prompts and receive responses
- Files -- file operations
- Config -- server configuration
- Provider -- LLM provider info
- Tools -- available tool listing
- Flow -- BPMN flow management (if brute_flow is available)
- Logging -- server logs
- VCS -- version control operations

## Dependencies

- [brute](https://github.com/general-intelligence-systems/brute) -- core agent library
- [rack](https://rubygems.org/gems/rack) -- HTTP interface
- [async-http](https://rubygems.org/gems/async-http) -- async HTTP support
